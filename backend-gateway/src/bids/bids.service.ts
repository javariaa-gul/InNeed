import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Bid, BidStatus } from './entities/bid.entity.js';
import { Job, JobStatus } from '../jobs/entities/job.entity.js';

@Injectable()
export class BidsService {
  constructor(
    @InjectRepository(Bid) private bidRepo: Repository<Bid>,
    @InjectRepository(Job) private jobRepo: Repository<Job>,
  ) {}

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

  async getBidHistoryForJob(jobId: number): Promise<Bid[]> {
    return this.bidRepo.find({
      where: { jobId },
      relations: ['seeker'],
      order: { createdAt: 'DESC' },
    });
  }
}