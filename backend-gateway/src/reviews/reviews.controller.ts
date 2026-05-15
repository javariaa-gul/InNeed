import {
  Controller, Post, Get, Param, Body, UseGuards,
  Request, ParseIntPipe, UseInterceptors, UploadedFiles,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { ReviewsService, CreateReviewDto } from './reviews.service.js';

@ApiTags('reviews')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly svc: ReviewsService) {}

  @Post()
  @UseInterceptors(
    FilesInterceptor('images', 5, { storage: memoryStorage() }),
  )
  async submit(
    @Request() req: any,
    @Body() dto: CreateReviewDto,
    @UploadedFiles() files: Express.Multer.File[],
  ) {
    // Handle file uploads to get URLs
    const imageUrls: string[] = [];
    if (files && files.length > 0) {
      for (const file of files) {
        imageUrls.push(file.originalname);
      }
    }
    return this.svc.submitReview(req.user.userId, dto, imageUrls);
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