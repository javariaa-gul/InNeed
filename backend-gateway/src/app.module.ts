import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { ConfigModule, ConfigService } from './config/index.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { JobsModule } from './jobs/jobs.module.js';
import { ReviewsModule } from './reviews/reviews.module.js';
import { ChatModule } from './chat/chat.module.js';
import { User } from './users/entities/user.entity.js';
import { Job } from './jobs/entities/job.entity.js';
import { Bid } from './bids/entities/bid.entity.js';
import { Review } from './reviews/entities/review.entity.js';
import { ReviewHash } from './reviews/entities/review-hash.entity.js';
import { ChatMessage } from './chat/entities/chat-message.entity.js';

@Module({
  imports: [
    ConfigModule,
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        ...configService.database,
        entities: [User, Job, Bid, Review, ReviewHash, ChatMessage],
      }),
    }),
    AuthModule,
    UsersModule,
    JobsModule,
    ReviewsModule,
    ChatModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}