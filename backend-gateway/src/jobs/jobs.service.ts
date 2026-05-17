import {
  Injectable, NotFoundException, ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { Repository, Not, In, DataSource } from 'typeorm';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { Job, JobStatus, PricingType, GenderPreference, UrgencyLevel } from './entities/job.entity.js';
import { Bid, BidStatus } from '../bids/entities/bid.entity.js';
import { Review } from '../reviews/entities/review.entity.js';
import { User } from '../users/entities/user.entity.js';
import { CreateJobDto } from './dto/create-job.dto.js';
import { ChatGateway } from '../chat/gateways/chat.gateway.js';

@Injectable()
export class JobsService {
  constructor(
    @InjectRepository(Job) private jobRepo: Repository<Job>,
    @InjectRepository(Bid) private bidRepo: Repository<Bid>,
    @InjectRepository(Review) private reviewRepo: Repository<Review>,
    @InjectRepository(User) private userRepo: Repository<User>,
    private readonly httpService: HttpService,
    private readonly chatGateway: ChatGateway,
    @InjectDataSource() private dataSource: DataSource,
  ) { }

  // ── CREATE JOB ─────────────────────────────────────────────────────────────
  async createJob(posterId: number, dto: CreateJobDto): Promise<Job> {
    const job = this.jobRepo.create({
      posterId,
      title: dto.title.trim(),
      description: dto.description.trim(),
      skillRequired: dto.skillRequired?.trim(),
      pricingType: (dto.pricingType as PricingType) ?? PricingType.FIXED,
      price: dto.price,
      genderPreference: (dto.genderPreference as GenderPreference) ?? GenderPreference.ANY,
      urgency: (dto.urgency as UrgencyLevel) ?? UrgencyLevel.FLEXIBLE,
      locationLat: dto.locationLat,
      locationLon: dto.locationLon,
      locationAddress: dto.locationAddress?.trim(),
      isRemote: dto.isRemote ?? false,
      estimatedHours: dto.estimatedHours,
      requiredByTime: dto.requiredByTime,
      attachmentUrls: dto.attachmentUrls,
      status: JobStatus.OPEN,
    });
    const saved = await this.jobRepo.save(job);

    this.dispatchToAI(saved).catch(() => { });
    return saved;
  }

  private async dispatchToAI(job: Job): Promise<void> {
    try {
      const aiUrl = process.env.AI_SERVICE_URL ?? 'http://ai-service:8000';
      
      // ✅ IMPROVED: Calculate urgency_minutes from actual deadline if provided
      let urgencyMins: number;
      
      if (job.requiredByTime) {
        // If requiredByTime is provided, calculate minutes until deadline
        const deadlineTime = new Date(job.requiredByTime).getTime();
        const nowTime = new Date().getTime();
        urgencyMins = Math.max(Math.floor((deadlineTime - nowTime) / 60000), 15); // Min 15 mins
      } else {
        // Fallback to urgency level
        urgencyMins = job.urgency === 'urgent' ? 30 : job.urgency === 'today' ? 240 : 1440;
      }

      const res = await firstValueFrom(
        this.httpService.post(`${aiUrl}/match`, {
          job_id: job.id,
          lat: job.locationLat ?? 24.8607,
          lon: job.locationLon ?? 67.0011,
          urgency_minutes: urgencyMins,
        }),
      );

      const ids: number[] = res.data?.targeted_seeker_ids ?? [];
      await this.jobRepo.update(job.id, { targetedSeekerIds: JSON.stringify(ids) });

      if (ids.length > 0) {
        this.chatGateway.sendJobCard(ids, {
          id: job.id,
          title: job.title,
          description: job.description,
          price: job.price,
          pricingType: job.pricingType,
          urgency: job.urgency,
          isRemote: job.isRemote,
          locationAddress: job.locationAddress,
          skillRequired: job.skillRequired,
          genderPreference: job.genderPreference,
          estimatedHours: job.estimatedHours,
          requiredByTime: job.requiredByTime,
          createdAt: job.createdAt,
        });
      }
    } catch (error) {
      console.error("AI Dispatch Failed:", error instanceof Error ? error.message : error);
    }
  }

  // ── SEEKER FEED ────────────────────────────────────────────────────────────
  async getFeedForSeeker(seekerId: number): Promise<Job[]> {
    const openJobs = await this.jobRepo.find({
      where: { status: JobStatus.OPEN },
      relations: ['poster'],
      order: { createdAt: 'DESC' },
    });

    const myBids = await this.bidRepo.find({ where: { seekerId } });
    const interactedIds = new Set(myBids.map((b) => b.jobId));

    return openJobs.filter((j) => {
      if (interactedIds.has(j.id)) return false;

      // ✅ FIXED: Only show job if targetedSeekerIds explicitly includes this seeker
      // If targetedSeekerIds is null/empty, job does NOT show to anyone
      if (j.targetedSeekerIds) {
        try {
          const rawIds = typeof j.targetedSeekerIds === 'string'
            ? JSON.parse(j.targetedSeekerIds)
            : j.targetedSeekerIds;
          const ids = Array.isArray(rawIds) ? rawIds.map(Number) : [];
          return ids.includes(Number(seekerId));
        } catch (e) {
          console.error("Filter Error for Job:", j.id, e);
          return false;
        }
      }
      
      // ✅ Job has no targetedSeekerIds (AI matching not completed or no matches)
      // → Do NOT show to any seeker
      return false;
    });
  }

  // ── POSTER'S JOBS ──────────────────────────────────────────────────────────
  async getMyPostedJobs(posterId: number): Promise<Job[]> {
    return this.jobRepo.find({
      where: { posterId },
      order: { createdAt: 'DESC' },
    });
  }

  async getPostersActiveJob(posterId: number): Promise<Job | null> {
    return this.jobRepo.findOne({
      where: { posterId, status: JobStatus.ACTIVE },
      relations: ['acceptedSeeker'],
    });
  }

  // ── BIDS FOR A JOB ─────────────────────────────────────────────────────────
  async getBidsForJob(jobId: number, posterId: number): Promise<Bid[]> {
    const job = await this.jobRepo.findOne({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.posterId !== posterId) throw new ForbiddenException();
    return this.bidRepo.find({
      where: { jobId, status: BidStatus.PENDING },
      relations: ['seeker'],
      order: { createdAt: 'ASC' },
    });
  }

  // ── PLACE BID (WITH COUNTER-BID SUPPORT) ───────────────────────────────────
  async placeBid(seekerId: number, jobId: number, offeredPrice: number, message?: string): Promise<Bid> {
    const job = await this.jobRepo.findOne({ where: { id: jobId, status: JobStatus.OPEN } });
    if (!job) throw new NotFoundException('Job not available');
    if (job.acceptedSeekerId === seekerId) throw new BadRequestException('Already accepted');

    const existing = await this.bidRepo.findOne({ where: { jobId, seekerId, status: BidStatus.PENDING } });
    
    if (existing) {
      const previousPrice = existing.offeredPrice;
      await this.bidRepo.update(existing.id, { offeredPrice, message });
      const updated = await this.bidRepo.findOne({ 
        where: { id: existing.id }, 
        relations: ['seeker'] 
      });
      
      // 🔥 Send counter-offer notification to poster
      this.chatGateway.sendToUser(job.posterId, 'bid_updated', {
        bidId: updated!.id,
        jobId: jobId,
        jobTitle: job.title,
        seekerId: seekerId,
        seekerName: updated!.seeker?.fullName,
        offeredPrice: offeredPrice,
        previousPrice: previousPrice,
        message: message,
        isCounterOffer: true,
      });
      
      return updated!;
    }

    const bid = this.bidRepo.create({ jobId, seekerId, offeredPrice, message, status: BidStatus.PENDING });
    const saved = await this.bidRepo.save(bid);
    const full = await this.bidRepo.findOne({ where: { id: saved.id }, relations: ['seeker'] });

    this.chatGateway.sendToUser(job.posterId, 'new_bid', {
      bidId: saved.id,
      jobId: jobId,
      jobTitle: job.title,
      seekerName: full!.seeker?.fullName,
      offeredPrice: offeredPrice,
      message: message,
    });
    
    return full!;
  }

  // ── REJECT JOB (swipe left) ────────────────────────────────────────────────
  async rejectJob(seekerId: number, jobId: number): Promise<void> {
    const existing = await this.bidRepo.findOne({ where: { jobId, seekerId } });
    if (!existing) {
      await this.bidRepo.save(this.bidRepo.create({ jobId, seekerId, offeredPrice: 0, status: BidStatus.REJECTED }));
    }
  }

  // ── ACCEPT BID ─────────────────────────────────────────────────────────────
  async acceptBid(posterId: number, jobId: number, bidId: number): Promise<Job> {
    const job = await this.jobRepo.findOne({ where: { id: jobId, posterId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.status !== JobStatus.OPEN) throw new BadRequestException('Job is not open');

    const bid = await this.bidRepo.findOne({ where: { id: bidId, jobId }, relations: ['seeker'] });
    if (!bid) throw new NotFoundException('Bid not found');

    await this.bidRepo.update(bidId, { status: BidStatus.ACCEPTED });

    await this.bidRepo
      .createQueryBuilder()
      .update(Bid)
      .set({ status: BidStatus.EXPIRED })
      .where('jobId = :jobId AND id != :bidId AND status = :s', {
        jobId, bidId, s: BidStatus.PENDING,
      })
      .execute();

    await this.jobRepo.update(jobId, { status: JobStatus.ACTIVE, acceptedSeekerId: bid.seekerId });
    const updated = await this.jobRepo.findOne({ where: { id: jobId } });

    this.chatGateway.sendToUser(bid.seekerId, 'bid_accepted', {
      jobId, jobTitle: job.title, posterId,
    });

    return updated!;
  }

  // ── ACCEPT COUNTER BID (WITH TRACKING START) ───────────────────────────────
  async acceptCounterBid(posterId: number, jobId: number, bidId: number): Promise<Job> {
    const job = await this.jobRepo.findOne({ where: { id: jobId, posterId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.status !== JobStatus.OPEN) throw new BadRequestException('Job is not open');

    const bid = await this.bidRepo.findOne({ where: { id: bidId, jobId }, relations: ['seeker'] });
    if (!bid) throw new NotFoundException('Bid not found');

    // Accept this bid
    await this.bidRepo.update(bidId, { status: BidStatus.ACCEPTED });

    // Expire all other pending bids
    await this.bidRepo
      .createQueryBuilder()
      .update(Bid)
      .set({ status: BidStatus.EXPIRED })
      .where('jobId = :jobId AND id != :bidId AND status = :s', {
        jobId, bidId, s: BidStatus.PENDING,
      })
      .execute();

    // ✅ TRACKING SYSTEM START - Job becomes ACTIVE
    await this.jobRepo.update(jobId, { 
      status: JobStatus.ACTIVE, 
      acceptedSeekerId: bid.seekerId 
    });
    
    const updated = await this.jobRepo.findOne({ where: { id: jobId } });

    // ✅ Notify seeker that counter-offer was accepted
    this.chatGateway.sendToUser(bid.seekerId, 'counter_bid_accepted', {
      jobId,
      jobTitle: job.title,
      acceptedPrice: bid.offeredPrice,
      posterId: posterId,
      message: 'Your counter offer was accepted! Job is now active.',
    });

    // ✅ Notify poster that acceptance was successful
    this.chatGateway.sendToUser(posterId, 'counter_acceptance_confirmed', {
      jobId,
      jobTitle: job.title,
      acceptedSeekerName: bid.seeker?.fullName,
      acceptedPrice: bid.offeredPrice,
    });

    return updated!;
  }

  // ── REJECT COUNTER BID ─────────────────────────────────────────────────────
  async rejectCounterBid(posterId: number, jobId: number, bidId: number): Promise<{ message: string }> {
    const job = await this.jobRepo.findOne({ where: { id: jobId, posterId } });
    if (!job) throw new NotFoundException('Job not found');

    const bid = await this.bidRepo.findOne({ where: { id: bidId, jobId }, relations: ['seeker'] });
    if (!bid) throw new NotFoundException('Bid not found');

    // Update bid status to REJECTED
    await this.bidRepo.update(bidId, { status: BidStatus.REJECTED });

    // Notify seeker that counter-offer was rejected
    this.chatGateway.sendToUser(bid.seekerId, 'counter_bid_rejected', {
      jobId,
      jobTitle: job.title,
      posterId: posterId,
      message: 'Your counter offer was rejected by the poster.',
    });

    return { message: 'Counter offer rejected successfully' };
  }

  // ── COMPLETE JOB (TRIGGERS REVIEW) ─────────────────────────────────────────
  async completeJob(userId: number, jobId: number): Promise<Job> {
    const job = await this.jobRepo.findOne({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.posterId !== userId && job.acceptedSeekerId !== userId) {
      throw new ForbiddenException('Not authorized to complete this job');
    }
    if (job.status === JobStatus.COMPLETE) {
      throw new BadRequestException('Job is already completed');
    }
    if (job.status === JobStatus.CANCELLED) {
      throw new BadRequestException('Cancelled jobs cannot be completed');
    }
    if (job.status !== JobStatus.ACTIVE) {
      throw new BadRequestException('Job is not currently active');
    }
    if (!job.acceptedSeekerId) {
      throw new BadRequestException('No worker assigned to this job');
    }

    await this.jobRepo.update(jobId, { status: JobStatus.COMPLETE });
    const updated = await this.jobRepo.findOne({ where: { id: jobId } });

    // ✅ Notify both parties to submit reviews
    this.chatGateway.sendToUser(job.posterId, 'job_completed', {
      jobId,
      revieweeId: job.acceptedSeekerId,
      message: 'Job completed! Please submit your review.',
    });

    this.chatGateway.sendToUser(job.acceptedSeekerId, 'job_completed', {
      jobId,
      revieweeId: job.posterId,
      message: 'Job completed! Please submit your review.',
    });

    return updated!;
  }

  // ── RE-LIST JOB ────────────────────────────────────────────────────────────
  async updateJobStatus(userId: number, jobId: number, status: string): Promise<Job> {
    const job = await this.jobRepo.findOne({ where: { id: jobId } });
    if (!job) throw new NotFoundException('Job not found');
    if (job.posterId !== userId && job.acceptedSeekerId !== userId) {
      throw new ForbiddenException('Not authorized');
    }
    // Map frontend-friendly status keys to internal JobStatus enum values
    const mapping: Record<string, JobStatus> = {
      accepted: JobStatus.ACTIVE,
      started: JobStatus.ACTIVE,
      in_progress: JobStatus.ACTIVE,
      active: JobStatus.ACTIVE,
      open: JobStatus.OPEN,
      complete: JobStatus.COMPLETE,
      completed: JobStatus.COMPLETE,
      cancelled: JobStatus.CANCELLED,
    };

    const mapped = mapping[status.toLowerCase().trim()];
    if (!mapped) throw new BadRequestException('Invalid status');

    if (mapped === JobStatus.ACTIVE) {
      if (job.status !== JobStatus.ACTIVE) {
        throw new BadRequestException('Job is not currently active');
      }
      if (!job.acceptedSeekerId) {
        throw new BadRequestException('No worker is assigned to this job');
      }
    }

    await this.jobRepo.update(jobId, { status: mapped });
    const updated = await this.jobRepo.findOne({ where: { id: jobId } });

    // Notify both parties of status update without failing the request if notifications fail.
    try {
      this.chatGateway.sendToUser(job.posterId, 'job_status_updated', { jobId, status });
    } catch (error) {
      console.error('Failed to notify poster of job status update:', error);
    }

    if (job.acceptedSeekerId) {
      try {
        this.chatGateway.sendToUser(job.acceptedSeekerId, 'job_status_updated', { jobId, status });
      } catch (error) {
        console.error('Failed to notify seeker of job status update:', error);
      }
    }

    return updated!;
  }

  async relistJob(posterId: number, jobId: number): Promise<Job> {
    const job = await this.jobRepo.findOne({ where: { id: jobId, posterId } });
    if (!job) throw new NotFoundException('Job not found');

    await this.bidRepo
      .createQueryBuilder()
      .update(Bid)
      .set({ status: BidStatus.PENDING })
      .where('jobId = :jobId AND status = :s', { jobId, s: BidStatus.EXPIRED })
      .execute();

    await this.jobRepo.update(jobId, { status: JobStatus.OPEN, acceptedSeekerId: null as any });
    const updated = await this.jobRepo.findOne({ where: { id: jobId } });

    const bids = await this.bidRepo.find({ where: { jobId, status: BidStatus.PENDING } });
    for (const b of bids) {
      this.chatGateway.sendToUser(b.seekerId, 'job_relisted', { jobId, jobTitle: job.title });
    }
    return updated!;
  }

  async getJobById(id: number): Promise<Job> {
    const job = await this.jobRepo.findOne({ where: { id }, relations: ['poster'] });
    if (!job) throw new NotFoundException('Job not found');
    return job;
  }

  async getSeekersActiveJob(seekerId: number): Promise<Job | null> {
    return this.jobRepo.findOne({
      where: { acceptedSeekerId: seekerId, status: JobStatus.ACTIVE },
      relations: ['poster'],
    });
  }
}