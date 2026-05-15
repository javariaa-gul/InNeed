import { Controller, Get, Param, ParseIntPipe, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { BidsService } from './bids.service.js';

@ApiTags('bids')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('bids')
export class BidsController {
  constructor(private readonly bidsService: BidsService) {}

  @Get('job/:jobId')
  getBidsForJob(@Param('jobId', ParseIntPipe) jobId: number, @Request() req: any) {
    return this.bidsService.getBidsForJob(jobId, req.user.userId);
  }

  @Get('job/:jobId/history')
  getBidHistory(@Param('jobId', ParseIntPipe) jobId: number) {
    return this.bidsService.getBidHistoryForJob(jobId);
  }
}