import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Bid } from './entities/bid.entity.js';
import { Job } from '../jobs/entities/job.entity.js';
import { BidsService } from './bids.service.js';
import { BidsController } from './bids.controller.js';

@Module({
  imports: [TypeOrmModule.forFeature([Bid, Job])],
  providers: [BidsService],
  controllers: [BidsController],
  exports: [BidsService],
})
export class BidsModule {}