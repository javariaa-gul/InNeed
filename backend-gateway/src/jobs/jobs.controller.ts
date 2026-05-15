import {
  Controller, Get, Post, Body, Param, UseGuards,
  Request, Delete, ParseIntPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { JobsService } from './jobs.service.js';
import { CreateJobDto } from './dto/create-job.dto.js';

@ApiTags('jobs')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('jobs')
export class JobsController {
  constructor(private readonly svc: JobsService) {}

  @Post()
  create(@Request() req: any, @Body() dto: CreateJobDto) {
    return this.svc.createJob(req.user.userId, dto);
  }

  @Get('mine')
  myJobs(@Request() req: any) {
    return this.svc.getMyPostedJobs(req.user.userId);
  }

  @Get('feed')
  feed(@Request() req: any) {
    return this.svc.getFeedForSeeker(req.user.userId);
  }

  @Get('active')
  activeJob(@Request() req: any) {
    return this.svc.getSeekersActiveJob(req.user.userId);
  }

  @Get('poster/active')
  posterActiveJob(@Request() req: any) {
    return this.svc.getPostersActiveJob(req.user.userId);
  }

  @Get(':id')
  getOne(@Param('id', ParseIntPipe) id: number) {
    return this.svc.getJobById(id);
  }

  @Get(':id/bids')
  getBids(@Param('id', ParseIntPipe) id: number, @Request() req: any) {
    return this.svc.getBidsForJob(id, req.user.userId);
  }

  @Post(':id/bids')
  placeBid(
    @Param('id', ParseIntPipe) jobId: number,
    @Request() req: any,
    @Body() body: { offeredPrice: number; message?: string },
  ) {
    return this.svc.placeBid(req.user.userId, jobId, body.offeredPrice, body.message);
  }

  @Post(':id/bids/:bidId/accept')
  acceptBid(
    @Param('id', ParseIntPipe) jobId: number,
    @Param('bidId', ParseIntPipe) bidId: number,
    @Request() req: any,
  ) {
    return this.svc.acceptBid(req.user.userId, jobId, bidId);
  }

  // ✅ NEW: Accept counter-bid and start tracking
  @Post(':id/bids/:bidId/counter/accept')
  acceptCounterBid(
    @Param('id', ParseIntPipe) jobId: number,
    @Param('bidId', ParseIntPipe) bidId: number,
    @Request() req: any,
  ) {
    return this.svc.acceptCounterBid(req.user.userId, jobId, bidId);
  }

  // ✅ NEW: Reject counter-bid
  @Post(':id/bids/:bidId/counter/reject')
  rejectCounterBid(
    @Param('id', ParseIntPipe) jobId: number,
    @Param('bidId', ParseIntPipe) bidId: number,
    @Request() req: any,
  ) {
    return this.svc.rejectCounterBid(req.user.userId, jobId, bidId);
  }

  @Post(':id/reject')
  rejectJob(@Param('id', ParseIntPipe) jobId: number, @Request() req: any) {
    return this.svc.rejectJob(req.user.userId, jobId);
  }

  @Post(':id/complete')
  complete(@Param('id', ParseIntPipe) jobId: number, @Request() req: any) {
    return this.svc.completeJob(req.user.userId, jobId);
  }

  @Post(':id/relist')
  relist(@Param('id', ParseIntPipe) jobId: number, @Request() req: any) {
    return this.svc.relistJob(req.user.userId, jobId);
  }
}