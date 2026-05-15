import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { Job } from './entities/job.entity.js';
import { Bid } from '../bids/entities/bid.entity.js';
import { Review } from '../reviews/entities/review.entity.js';
import { User } from '../users/entities/user.entity.js';
import { ChatMessage } from '../chat/entities/chat-message.entity.js';
import { JobsService } from './jobs.service.js';
import { JobsController } from './jobs.controller.js';
import { ChatGateway } from '../chat/gateways/chat.gateway.js';
import { AuthModule } from '../auth/auth.module.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Job, Bid, Review, User, ChatMessage]),
    HttpModule,
    AuthModule,
  ],
  providers: [JobsService, ChatGateway],
  controllers: [JobsController],
  exports: [JobsService, ChatGateway],
})
export class JobsModule {}
