import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from './entities/review.entity.js';
import { ReviewHash } from './entities/review-hash.entity.js';
import { Job, JobStatus } from '../jobs/entities/job.entity.js';
import { User } from '../users/entities/user.entity.js';
import { BlockchainService, ReviewBlockchainData } from './blockchain.service.js';

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
  private readonly logger = new Logger(ReviewsService.name);

  constructor(
    @InjectRepository(Review) private readonly reviewRepo: Repository<Review>,
    @InjectRepository(ReviewHash) private readonly hashRepo: Repository<ReviewHash>,
    @InjectRepository(Job) private readonly jobRepo: Repository<Job>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    private readonly blockchainService: BlockchainService,
  ) {}

  /**
   * Submit a new review with blockchain immutability
   */
  async submitReview(
    reviewerId: number,
    dto: CreateReviewDto,
    beforeImageUrl: string,
    afterImageUrl: string,
  ): Promise<Review> {
    this.logger.log(`[Review Submit] Starting for jobId=${dto.jobId}, reviewerId=${reviewerId}`);

    try {
      // Validate inputs
      const jobId = Number(dto.jobId);
      if (!Number.isInteger(jobId) || jobId <= 0) {
        throw new BadRequestException('Invalid job ID');
      }

      if (!Number.isInteger(Number(dto.overallRating)) || dto.overallRating < 1 || dto.overallRating > 5) {
        throw new BadRequestException('Overall rating must be between 1 and 5');
      }

      if (!beforeImageUrl || !afterImageUrl) {
        throw new BadRequestException('Before and after images are required');
      }

      // Verify job exists
      const job = await this.jobRepo.findOne({
        where: { id: jobId },
        relations: ['poster', 'acceptedSeeker'],
      });

      if (!job) {
        this.logger.warn(`[Review Submit] Job ${jobId} not found`);
        throw new NotFoundException('Job not found');
      }

      // Verify job is complete
      if (job.status !== JobStatus.COMPLETE) {
        throw new ForbiddenException('Job must be completed before submitting review');
      }

      // Verify reviewer is part of the job
      const isJobParticipant = job.posterId === reviewerId || job.acceptedSeekerId === reviewerId;
      if (!isJobParticipant) {
        throw new ForbiddenException('You are not part of this job');
      }

      // Check if already reviewed
      const existingReview = await this.reviewRepo.findOne({
        where: { jobId, reviewerId },
      });

      if (existingReview) {
        this.logger.log(`[Review Submit] Review already exists for jobId=${jobId}, reviewerId=${reviewerId}`);
        return existingReview;
      }

      // Determine reviewee
      const revieweeId = job.posterId === reviewerId ? job.acceptedSeekerId : job.posterId;
      const revieweeRole = job.posterId === reviewerId ? 'worker' : 'employer';

      if (!revieweeId) {
        throw new BadRequestException('Cannot determine review recipient');
      }

      // Create review entity
      const reviewPayload: Partial<Review> = {
        jobId,
        reviewerId,
        revieweeId,
        revieweeRole,
        overallRating: Number(dto.overallRating),
        workQualityRating: dto.workQualityRating ? Number(dto.workQualityRating) : undefined,
        behaviorRating: dto.behaviorRating ? Number(dto.behaviorRating) : undefined,
        smoothnessRating: dto.smoothnessRating ? Number(dto.smoothnessRating) : undefined,
        comment: dto.comment?.trim() || undefined,
        beforeImageUrl,
        afterImageUrl,
      };

      const review = this.reviewRepo.create(reviewPayload);
      const savedReview = await this.reviewRepo.save(review);

      this.logger.log(`[Review Submit] Review saved with id=${savedReview.id}`);

      // ╔════════════════════════════════════════════════════════════════════╗
      // ║  BLOCKCHAIN: Create immutable record                             ║
      // ╚════════════════════════════════════════════════════════════════════╝

      try {
        const previousHashRecord = await this.hashRepo.findOne({
          order: { id: 'DESC' },
        });

        const previousHash = previousHashRecord?.hash || this.blockchainService['genesisHash'] ||
          '0000000000000000000000000000000000000000000000000000000000000000';

        // Prepare blockchain data with all immutable fields
        const blockchainData: ReviewBlockchainData = {
          reviewId: savedReview.id,
          jobId: savedReview.jobId,
          reviewerId: savedReview.reviewerId,
          revieweeId: savedReview.revieweeId,
          revieweeRole: savedReview.revieweeRole,
          overallRating: savedReview.overallRating,
          workQualityRating: savedReview.workQualityRating,
          behaviorRating: savedReview.behaviorRating,
          smoothnessRating: savedReview.smoothnessRating,
          comment: savedReview.comment || '',
          beforeImageUrl: savedReview.beforeImageUrl,
          afterImageUrl: savedReview.afterImageUrl,
          createdAt: savedReview.createdAt.toISOString(),
        };

        // Create blockchain entry
        const blockchainEntry = this.blockchainService.createBlockchainEntry(blockchainData, previousHash);

        // Save to immutable ledger
        const savedHash = await this.hashRepo.save({
          reviewId: blockchainEntry.reviewId,
          hash: blockchainEntry.hash,
          previousHash: blockchainEntry.previousHash,
          isVerified: true,
        });

        // Update review with blockchain hash
        await this.reviewRepo.update(savedReview.id, {
          blockchainHash: blockchainEntry.hash,
        });

        savedReview.blockchainHash = blockchainEntry.hash;

        this.logger.log(
          `[Review Submit] Review ${savedReview.id} added to blockchain with hash ${blockchainEntry.hash}`,
        );
      } catch (blockchainError) {
        this.logger.error('[Review Submit] Blockchain operation failed', blockchainError);
        throw new InternalServerErrorException('Failed to record review in blockchain');
      }

      // Recalculate reviewer/reviewee rating
      await this.recalculateUserRating(revieweeId, revieweeRole);

      this.logger.log(`[Review Submit] Review ${savedReview.id} completed successfully`);
      return savedReview;
    } catch (error) {
      this.logger.error('[Review Submit] Error:', error);
      throw error;
    }
  }

  /**
   * Recalculate user rating based on all reviews
   */
  private async recalculateUserRating(userId: number, role: 'worker' | 'employer'): Promise<void> {
    try {
      const reviews = await this.reviewRepo.find({
        where: { revieweeId: userId, revieweeRole: role },
      });

      if (!reviews.length) return;

      const averageRating = reviews.reduce((sum, r) => sum + r.overallRating, 0) / reviews.length;

      const updateData =
        role === 'worker'
          ? {
              workerRating: Number(averageRating.toFixed(1)),
              workerRatingCount: reviews.length,
            }
          : {
              employerRating: Number(averageRating.toFixed(1)),
              employerRatingCount: reviews.length,
            };

      await this.userRepo.update(userId, updateData);
      this.logger.debug(`[Rating Update] User ${userId} (${role}) rating updated: ${averageRating.toFixed(1)}`);
    } catch (error) {
      this.logger.error(`[Rating Update] Failed for user ${userId}`, error);
      // Don't throw - this is non-critical
    }
  }

  /**
   * Check if user has reviewed a job
   */
  async hasReviewed(reviewerId: number, jobId: number): Promise<boolean> {
    const review = await this.reviewRepo.findOne({
      where: { jobId, reviewerId },
    });
    return !!review;
  }

  /**
   * Get all reviews for a user
   */
  async getReviewsForUser(userId: number): Promise<Review[]> {
    return this.reviewRepo.find({
      where: { revieweeId: userId },
      relations: ['reviewer'],
      order: { createdAt: 'DESC' },
      take: 50, // Limit to recent reviews
    });
  }

  /**
   * Verify a single review against blockchain
   */
  async verifyReview(
    reviewId: number,
  ): Promise<{
    isValid: boolean;
    hash: string;
    inChain: boolean;
    message: string;
  }> {
    try {
      const review = await this.reviewRepo.findOne({
        where: { id: reviewId },
      });

      if (!review) {
        throw new NotFoundException(`Review ${reviewId} not found`);
      }

      const chainRecord = await this.hashRepo.findOne({
        where: { reviewId },
      });

      if (!chainRecord) {
        return {
          isValid: false,
          hash: review.blockchainHash || '',
          inChain: false,
          message: 'Review not found in blockchain ledger',
        };
      }

      // Get previous hash for verification
      const previousRecord = await this.hashRepo
        .createQueryBuilder('hash')
        .where('hash.id < :id', { id: chainRecord.id })
        .orderBy('hash.id', 'DESC')
        .take(1)
        .getOne();

      const previousHash = previousRecord?.hash || 
        '0000000000000000000000000000000000000000000000000000000000000000';

      // Reconstruct blockchain data for verification
      const blockchainData: ReviewBlockchainData = {
        reviewId: review.id,
        jobId: review.jobId,
        reviewerId: review.reviewerId,
        revieweeId: review.revieweeId,
        revieweeRole: review.revieweeRole,
        overallRating: review.overallRating,
        workQualityRating: review.workQualityRating,
        behaviorRating: review.behaviorRating,
        smoothnessRating: review.smoothnessRating,
        comment: review.comment || '',
        beforeImageUrl: review.beforeImageUrl,
        afterImageUrl: review.afterImageUrl,
        createdAt: review.createdAt.toISOString(),
      };

      const isValid = this.blockchainService.verifyReviewHash(
        blockchainData,
        chainRecord.hash,
        chainRecord.previousHash,
      );

      return {
        isValid,
        hash: chainRecord.hash,
        inChain: true,
        message: isValid 
          ? 'Review verified and immutable in blockchain'
          : 'Review exists but hash mismatch (tampering detected)',
      };
    } catch (error) {
      this.logger.error(`[Verify Review] Error for reviewId=${reviewId}:`, error);
      throw error;
    }
  }

  /**
   * Verify entire blockchain integrity
   */
  async verifyFullChain(): Promise<{
    isValid: boolean;
    totalReviews: number;
    brokenAt?: number;
    message: string;
  }> {
    try {
      this.logger.log('[Verify Chain] Starting full chain verification');

      const allEntries = await this.hashRepo.find({
        order: { id: 'ASC' },
      });

      if (!allEntries.length) {
        return {
          isValid: true,
          totalReviews: 0,
          message: 'Empty blockchain (valid)',
        };
      }

      // Convert ReviewHash to BlockchainEntry format
      const entries = allEntries.map(h => ({
        reviewId: h.reviewId,
        hash: h.hash,
        previousHash: h.previousHash,
        timestamp: h.createdAt.toISOString(),
        isVerified: h.isVerified,
      }));

      const result = this.blockchainService.verifyBlockchainIntegrity(entries);

      this.logger.log(
        `[Verify Chain] Verification complete: ${result.isValid ? 'VALID' : 'BROKEN'} ` +
        `(${allEntries.length} reviews)`,
      );

      return {
        isValid: result.isValid,
        totalReviews: allEntries.length,
        brokenAt: result.brokenAt,
        message: result.message,
      };
    } catch (error) {
      this.logger.error('[Verify Chain] Error:', error);
      throw new InternalServerErrorException('Chain verification failed');
    }
  }

  /**
   * Get full blockchain history
   */
  async getChainHistory(): Promise<ReviewHash[]> {
    return this.hashRepo.find({
      order: { id: 'ASC' },
      take: 100,
    });
  }

  /**
   * Get blockchain health status
   */
  getBlockchainHealth(): any {
    return this.blockchainService.getHealth();
  }
}