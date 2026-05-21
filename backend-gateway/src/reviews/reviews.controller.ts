import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  UseGuards,
  Request,
  ParseIntPipe,
  UseInterceptors,
  UploadedFiles,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { ReviewsService, CreateReviewDto } from './reviews.service.js';
// Cloudinary removed: image uploads disabled

@ApiTags('reviews')
@Controller('reviews')
export class ReviewsController {
  private readonly logger = new Logger(ReviewsController.name);

  constructor(private readonly reviewsService: ReviewsService) {}

  /**
   * Submit a new review with before/after images
   * Images are uploaded to Cloudinary, review is stored with blockchain immutability
   */
  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Submit a review for a completed job' })
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'beforeImage', maxCount: 1 },
        { name: 'afterImage', maxCount: 1 },
      ],
      { storage: memoryStorage() },
    ),
  )
  async submitReview(
    @Request() req: any,
    @Body() dto: CreateReviewDto,
    @UploadedFiles()
    files: {
      beforeImage?: Express.Multer.File[];
      afterImage?: Express.Multer.File[];
    },
  ) {
    try {
      this.logger.log(`[Submit Review] Incoming request from userId=${req.user.userId}, jobId=${dto.jobId}`);

      // Image uploads are disabled. Reviews can be submitted without images.
      // Any uploaded files will be ignored.
      const beforeFile = files?.beforeImage?.[0];
      const afterFile = files?.afterImage?.[0];

      if (beforeFile || afterFile) {
        this.logger.log('[Submit Review] Received image files but image upload is disabled; ignoring files.');
      }

      const beforeImageUrl = undefined;
      const afterImageUrl = undefined;

      // Submit review with blockchain
      const review = await this.reviewsService.submitReview(req.user.userId, dto, beforeImageUrl, afterImageUrl);

      this.logger.log(
        `[Submit Review] Review ${review.id} submitted successfully with blockchain hash`,
      );

      return {
        success: true,
        message: 'Review submitted successfully and recorded on blockchain',
        review,
      };
    } catch (error) {
      this.logger.error('[Submit Review] Error:', error);
      throw error;
    }
  }

  /**
   * Check if user has already reviewed a job
   */
  @Get('check/:jobId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Check if user has reviewed a specific job' })
  async checkReviewStatus(@Request() req: any, @Param('jobId', ParseIntPipe) jobId: number) {
    const hasReviewed = await this.reviewsService.hasReviewed(req.user.userId, jobId);
    return {
      jobId,
      hasReviewed,
    };
  }

  /**
   * Get all reviews for a user (employer or worker)
   */
  @Get('user/:userId')
  @ApiOperation({ summary: 'Get all reviews received by a user' })
  async getReviewsForUser(@Param('userId', ParseIntPipe) userId: number) {
    const reviews = await this.reviewsService.getReviewsForUser(userId);
    return {
      success: true,
      userId,
      reviewCount: reviews.length,
      reviews,
    };
  }

  /**
   * Verify a specific review against the blockchain
   */
  @Get('verify/:reviewId')
  @ApiOperation({ summary: 'Verify review authenticity and immutability on blockchain' })
  async verifyReview(@Param('reviewId', ParseIntPipe) reviewId: number) {
    const verification = await this.reviewsService.verifyReview(reviewId);
    return {
      reviewId,
      ...verification,
    };
  }

  /**
   * Verify entire blockchain integrity
   */
  @Get('chain/verify')
  @ApiOperation({ summary: 'Verify entire blockchain integrity for all reviews' })
  async verifyFullChain() {
    return await this.reviewsService.verifyFullChain();
  }

  /**
   * Get complete blockchain history
   */
  @Get('chain/history')
  @ApiOperation({ summary: 'Get complete blockchain history of all reviews' })
  async getChainHistory() {
    const history = await this.reviewsService.getChainHistory();
    return {
      success: true,
      count: history.length,
      ledger: history,
    };
  }

  /**
   * Get blockchain service health
   */
  @Get('chain/health')
  @ApiOperation({ summary: 'Check blockchain service health' })
  async getBlockchainHealth() {
    return this.reviewsService.getBlockchainHealth();
  }
}