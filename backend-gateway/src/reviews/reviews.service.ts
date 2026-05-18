import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from './entities/review.entity.js';
import { ReviewHash } from './entities/review-hash.entity.js';
import { Job, JobStatus } from '../jobs/entities/job.entity.js';
import { User } from '../users/entities/user.entity.js';
import { BlockchainService } from './blockchain.service.js';

export class CreateReviewDto {
  jobId!: number;
  overallRating!: number;
  workQualityRating?: number;
  behaviorRating?: number;
  smoothnessRating?: number;
  comment?: string;
}

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review) private reviewRepo: Repository<Review>,
    @InjectRepository(ReviewHash) private hashRepo: Repository<ReviewHash>,
    @InjectRepository(Job) private jobRepo: Repository<Job>,
    @InjectRepository(User) private userRepo: Repository<User>,
    private readonly blockchainService: BlockchainService,
  ) {}

  async submitReview(
    reviewerId: number,
    dto: CreateReviewDto,
    beforeImageUrl: string,
    afterImageUrl: string,
  ): Promise<Review> {
    const requestedJobId = Number(dto.jobId);
    console.log(`ReviewsService: submitReview called for jobId=${dto.jobId} (parsed=${requestedJobId}) by reviewer=${reviewerId}`);

    if (!Number.isInteger(requestedJobId) || requestedJobId <= 0) {
      console.error(`ReviewsService: invalid jobId in request: ${dto.jobId}`);
      throw new BadRequestException('Invalid or missing jobId');
    }

    const job = await this.jobRepo.findOne({ where: { id: requestedJobId } });
    if (!job) {
      console.error(`ReviewsService: job not found for id=${requestedJobId}`);
      throw new NotFoundException('Job not found');
    }
    if (job.status !== JobStatus.COMPLETE)
      throw new ForbiddenException('Job not complete yet');

    const isParty =
      job.posterId === reviewerId || job.acceptedSeekerId === reviewerId;
    if (!isParty) throw new ForbiddenException('Not part of this job');

    const alreadyReviewed = await this.reviewRepo.findOne({
      where: { jobId: dto.jobId, reviewerId },
    });
    if (alreadyReviewed) return alreadyReviewed;

    const revieweeId =
      job.posterId === reviewerId ? job.acceptedSeekerId : job.posterId;
    if (!revieweeId) {
      throw new BadRequestException('No reviewee available for this job yet');
    }
    const revieweeRole =
      job.posterId === reviewerId ? 'worker' : 'employer';

    if (!beforeImageUrl || !afterImageUrl) {
      throw new BadRequestException('Before and after images are required');
    }

    const imageUrls = [beforeImageUrl, afterImageUrl];

    const reviewPayload: Partial<Review> = {
      jobId: dto.jobId,
      reviewerId,
      revieweeId,
      revieweeRole,
      overallRating: Number(dto.overallRating),
      workQualityRating:
        dto.workQualityRating !== undefined
          ? Number(dto.workQualityRating)
          : undefined,
      behaviorRating:
        dto.behaviorRating !== undefined
          ? Number(dto.behaviorRating)
          : undefined,
      smoothnessRating:
        dto.smoothnessRating !== undefined
          ? Number(dto.smoothnessRating)
          : undefined,
      comment: dto.comment?.trim() || undefined,
      beforeImageUrl,
      afterImageUrl,
      imageUrls,
    };

    const review = this.reviewRepo.create(reviewPayload);

    const saved = await this.reviewRepo.save(review);

    // 🔗 FULL BLOCKCHAIN: Get previous hash for chain
    const lastHash = await this.hashRepo.findOne({
      where: {},
      order: { id: 'DESC' },
    });
    
    const previousHash = lastHash?.hash ?? '0000000000000000000000000000000000000000000000000000000000000000';

    // Generate blockchain hash with previous hash included
    const hash = await this.blockchainService.hashReviewWithPrevious({
      reviewId: saved.id,
      jobId: saved.jobId,
      reviewerId: saved.reviewerId,
      revieweeId: saved.revieweeId,
      overallRating: saved.overallRating,
      comment: saved.comment || '',
      imageUrls: saved.imageUrls || [],
      createdAt: saved.createdAt.toISOString(),
      previousHash: previousHash,
    });

    // Save hash to chain table
    await this.hashRepo.save({
      reviewId: saved.id,
      hash: hash,
      previousHash: previousHash,
      isVerified: false,
    });

    // Save hash to review table
    await this.reviewRepo.update(saved.id, { blockchainHash: hash });
    saved.blockchainHash = hash;

    await this.recalcRating(revieweeId, revieweeRole);
    return saved;
  }

  private async recalcRating(userId: number, role: string) {
    const reviews = await this.reviewRepo.find({
      where: { revieweeId: userId, revieweeRole: role },
    });
    if (!reviews.length) return;
    const avg = reviews.reduce((s, r) => s + r.overallRating, 0) / reviews.length;
    if (role === 'worker') {
      await this.userRepo.update(userId, {
        workerRating: +avg.toFixed(1),
        workerRatingCount: reviews.length,
      });
    } else {
      await this.userRepo.update(userId, {
        employerRating: +avg.toFixed(1),
        employerRatingCount: reviews.length,
      });
    }
  }

  async hasReviewed(reviewerId: number, jobId: number): Promise<boolean> {
    return !!(await this.reviewRepo.findOne({ where: { jobId, reviewerId } }));
  }

  async getReviewsForUser(userId: number): Promise<Review[]> {
    return this.reviewRepo.find({
      where: { revieweeId: userId },
      relations: ['reviewer'],
      order: { createdAt: 'DESC' },
    });
  }

  // 🔗 FULL BLOCKCHAIN: Verify entire chain
  async verifyFullChain(): Promise<{ isValid: boolean; brokenAt?: number }> {
    const allHashes = await this.hashRepo.find({
      order: { id: 'ASC' },
    });

    for (let i = 0; i < allHashes.length; i++) {
      const current = allHashes[i];
      
      // Verify current hash
      const isValid = await this.blockchainService.verifyReview(current.reviewId, current.hash);
      
      if (!isValid) {
        return { isValid: false, brokenAt: current.reviewId };
      }

      // Verify chain link (previous hash matches)
      if (i > 0) {
        const previous = allHashes[i - 1];
        if (current.previousHash !== previous.hash) {
          return { isValid: false, brokenAt: current.reviewId };
        }
      }
    }

    return { isValid: true };
  }

  async verifyReview(reviewId: number): Promise<{ isValid: boolean; hash: string; inChain: boolean }> {
    const review = await this.reviewRepo.findOne({ where: { id: reviewId } });
    if (!review) throw new NotFoundException('Review not found');
    
    const isValid = await this.blockchainService.verifyReview(reviewId, review.blockchainHash);
    
    const chainRecord = await this.hashRepo.findOne({ where: { reviewId } });
    
    return { 
      isValid, 
      hash: review.blockchainHash,
      inChain: !!chainRecord 
    };
  }

  async getChainHistory(): Promise<ReviewHash[]> {
    return this.hashRepo.find({
      order: { id: 'ASC' },
    });
  }
}