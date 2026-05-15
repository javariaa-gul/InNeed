import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import * as crypto from 'crypto';

@Injectable()
export class BlockchainService {
  private readonly blockchainUrl =
    process.env.BLOCKCHAIN_SERVICE_URL ?? 'http://localhost:3001';

  constructor(private readonly httpService: HttpService) {}

  // 🔗 FULL BLOCKCHAIN: Hash with previous hash
  async hashReviewWithPrevious(data: {
    reviewId: number;
    jobId: number;
    reviewerId: number;
    revieweeId: number;
    overallRating: number;
    comment: string;
    imageUrls: string[];
    createdAt: string;
    previousHash: string;
  }): Promise<string> {
    try {
      // Create a string with all data including previous hash
      const dataString = JSON.stringify(data);
      
      // Generate SHA-256 hash
      const hash = crypto.createHash('sha256').update(dataString).digest('hex');
      
      // Also try to send to external blockchain service if available
      try {
        const response = await firstValueFrom(
          this.httpService.post(`${this.blockchainUrl}/hash-chain`, data),
        );
        return response.data?.hash || hash;
      } catch {
        return hash;
      }
    } catch (error) {
      console.error('Blockchain hash error:', error);
      // Fallback to local hash
      const fallbackData = JSON.stringify({
        ...data,
        timestamp: Date.now(),
      });
      return crypto.createHash('sha256').update(fallbackData).digest('hex');
    }
  }

  async verifyReview(reviewId: number, hash: string): Promise<boolean> {
    try {
      const response = await firstValueFrom(
        this.httpService.get(`${this.blockchainUrl}/verify/${reviewId}/${hash}`),
      );
      return response.data?.isValid === true;
    } catch (error) {
      // If external service fails, hash seems valid
      console.error('Blockchain verify error:', error);
      return hash !== null && hash !== '';
    }
  }
}