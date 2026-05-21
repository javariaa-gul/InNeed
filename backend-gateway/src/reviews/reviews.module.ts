import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Review } from './entities/review.entity.js';
import { ReviewHash } from './entities/review-hash.entity.js';
import { Job } from '../jobs/entities/job.entity.js';
import { User } from '../users/entities/user.entity.js';
import { ReviewsService } from './reviews.service.js';
import { ReviewsController } from './reviews.controller.js';
import { BlockchainService } from './blockchain.service.js';
import { BlockchainController } from './blockchain.controller.js';
import { AuthModule } from '../auth/auth.module.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Review, ReviewHash, Job, User]),
    AuthModule,
  ],
  providers: [ReviewsService, BlockchainService],
  controllers: [ReviewsController, BlockchainController],
  exports: [ReviewsService],
})
export class ReviewsModule {}