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
import { CloudinaryService } from '../cloudinary/cloudinary.service.js';

@ApiTags('reviews')
@Controller('reviews')
export class ReviewsController {
  private readonly logger = new Logger(ReviewsController.name);

  constructor(
    private readonly reviewsService: ReviewsService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

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

      // Validate files
      const beforeFile = files?.beforeImage?.[0];
      const afterFile = files?.afterImage?.[0];

      if (!beforeFile) {
        throw new BadRequestException('Before image is required');
      }

      if (!afterFile) {
        throw new BadRequestException('After image is required');
      }

      // Validate file types and sizes
      const beforeIsImageMime = beforeFile.mimetype?.startsWith('image/');
      const beforeIsImageName = /\.(jpg|jpeg|png|gif|webp|bmp|heic|heif)$/i.test(
        beforeFile.originalname ?? '',
      );
      if (!beforeIsImageMime && !beforeIsImageName) {
        throw new BadRequestException('Before file must be an image');
      }

      const afterIsImageMime = afterFile.mimetype?.startsWith('image/');
      const afterIsImageName = /\.(jpg|jpeg|png|gif|webp|bmp|heic|heif)$/i.test(
        afterFile.originalname ?? '',
      );
      if (!afterIsImageMime && !afterIsImageName) {
        throw new BadRequestException('After file must be an image');
      }

      const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

      if (beforeFile.size > MAX_FILE_SIZE) {
        throw new BadRequestException('Before image size exceeds 5MB limit');
      }

      if (afterFile.size > MAX_FILE_SIZE) {
        throw new BadRequestException('After image size exceeds 5MB limit');
      }

      this.logger.log(
        `[Submit Review] Uploading images: before=${beforeFile.originalname} (${beforeFile.size}B), ` +
        `after=${afterFile.originalname} (${afterFile.size}B)`,
      );

      // Upload both images to Cloudinary in parallel
      let beforeImageUrl: string;
      let afterImageUrl: string;

      try {
        [beforeImageUrl, afterImageUrl] = await Promise.all([
          this.cloudinaryService.uploadImage(beforeFile, 'apka-hunar/reviews'),
          this.cloudinaryService.uploadImage(afterFile, 'apka-hunar/reviews'),
        ]);

        this.logger.log(
          `[Submit Review] Images uploaded successfully\n  Before: ${beforeImageUrl}\n  After: ${afterImageUrl}`,
        );
      } catch (uploadError) {
        this.logger.error('[Submit Review] Image upload failed', uploadError);
        throw new BadRequestException(`Image upload failed: ${uploadError.message}`);
      }

      // Submit review with blockchain
      const review = await this.reviewsService.submitReview(
        req.user.userId,
        dto,
        beforeImageUrl,
        afterImageUrl,
      );

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