import {
  Controller, Post, Get, Param, Body, UseGuards,
  Request, ParseIntPipe, UseInterceptors, UploadedFiles,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { ReviewsService, CreateReviewDto } from './reviews.service.js';
import { CloudinaryService } from '../cloudinary/cloudinary.service.js';

@ApiTags('reviews')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reviews')
export class ReviewsController {
  constructor(
    private readonly svc: ReviewsService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  @Post()
  @UseInterceptors(
    FilesInterceptor('images', 2, { storage: memoryStorage() }),
  )
  async submit(
    @Request() req: any,
    @Body() dto: CreateReviewDto,
    @UploadedFiles() files: Express.Multer.File[],
  ) {
    // Upload images to Cloudinary if provided
    let beforeImageUrl: string | undefined;
    let afterImageUrl: string | undefined;

    if (files && files.length > 0) {
      // Map files by field name or by order
      for (const file of files) {
        const url = await this.cloudinaryService.uploadImage(file);
        // First file = before, second file = after
        if (!beforeImageUrl) {
          beforeImageUrl = url;
        } else if (!afterImageUrl) {
          afterImageUrl = url;
        }
      }
    }

    return this.svc.submitReview(req.user.userId, dto, beforeImageUrl, afterImageUrl);
  }

  @Get('check/:jobId')
  check(
    @Request() req: any,
    @Param('jobId', ParseIntPipe) jobId: number,
  ) {
    return this.svc.hasReviewed(req.user.userId, jobId);
  }

  @Get('user/:userId')
  forUser(@Param('userId', ParseIntPipe) userId: number) {
    return this.svc.getReviewsForUser(userId);
  }

  @Get('verify/:reviewId')
  verify(@Param('reviewId', ParseIntPipe) reviewId: number) {
    return this.svc.verifyReview(reviewId);
  }

  // 🔗 Full blockchain endpoints
  @Get('chain/verify')
  verifyFullChain() {
    return this.svc.verifyFullChain();
  }

  @Get('chain/history')
  getChainHistory() {
    return this.svc.getChainHistory();
  }
}