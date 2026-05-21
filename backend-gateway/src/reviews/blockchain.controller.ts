import { Body, Controller, Get, Param, ParseIntPipe, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Logger } from '@nestjs/common';
import type { ReviewBlockchainData } from './blockchain.service.js';
import { BlockchainService } from './blockchain.service.js';

@ApiTags('blockchain')
@Controller()
export class BlockchainController {
  private readonly logger = new Logger(BlockchainController.name);
  constructor(private readonly blockchainService: BlockchainService) {}
  @Post('hash')
  async createEntry(@Body() data: ReviewBlockchainData) {
    try {
      const entry = this.blockchainService.createBlockchainEntry(data);
      return {
        success: true,
        hash: entry.hash,
        previousHash: entry.previousHash,
        timestamp: entry.timestamp,
        reviewId: entry.reviewId,
      };
    } catch (error) {
      this.logger.error('Error:', error);
      throw error;
    }
  }

  @Post('hash-chain')
  async createChainedEntry(@Body() data: ReviewBlockchainData & { previousHash?: string }) {
    try {
      const previousHash = data.previousHash || 
        '0000000000000000000000000000000000000000000000000000000000000000';
      const entry = this.blockchainService.createBlockchainEntry(
        data,
        previousHash,
      );
      return {
        success: true,
        hash: entry.hash,
        previousHash: entry.previousHash,
        timestamp: entry.timestamp,
        reviewId: entry.reviewId,
      };
    } catch (error) {
      this.logger.error('Error:', error);
      throw error;
    }
  }

  @Get('verify/:reviewId/:hash')
  async verifyEntry(
    @Param('reviewId', ParseIntPipe) reviewId: number,
    @Param('hash') hash: string,
  ) {
    const isValidFormat = /^[a-f0-9]{64}$/.test(hash);
    return { success: true, reviewId, hash, isValidFormat };
  }

  @Get('health')
  getHealth() {
    return this.blockchainService.getHealth();
  }
}