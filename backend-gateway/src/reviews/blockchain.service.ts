import { Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';

export interface ReviewBlockchainData {
  reviewId: number;
  jobId: number;
  reviewerId: number;
  revieweeId: number;
  revieweeRole: string;
  overallRating: number;
  workQualityRating?: number;
  behaviorRating?: number;
  smoothnessRating?: number;
  comment?: string;
  beforeImageUrl: string;
  afterImageUrl: string;
  createdAt: string;
}

export interface BlockchainEntry {
  reviewId: number;
  hash: string;
  previousHash: string;
  timestamp: string;
  isVerified: boolean;
}

@Injectable()
export class BlockchainService {
  private readonly logger = new Logger(BlockchainService.name);
  private readonly genesisHash = '0000000000000000000000000000000000000000000000000000000000000000';

  /**
   * Generate SHA256 hash from review data
   * Includes all review details to create immutable record
   */
  private generateHash(data: ReviewBlockchainData, previousHash: string): string {
    try {
      const content = JSON.stringify({
        reviewId: data.reviewId,
        jobId: data.jobId,
        reviewerId: data.reviewerId,
        revieweeId: data.revieweeId,
        revieweeRole: data.revieweeRole,
        overallRating: data.overallRating,
        workQualityRating: data.workQualityRating || 0,
        behaviorRating: data.behaviorRating || 0,
        smoothnessRating: data.smoothnessRating || 0,
        comment: data.comment || '',
        beforeImageUrl: data.beforeImageUrl,
        afterImageUrl: data.afterImageUrl,
        createdAt: data.createdAt,
        previousHash: previousHash, // Critical for blockchain integrity
      });

      this.logger.debug(`Hashing review data for reviewId: ${data.reviewId}`);
      return crypto.createHash('sha256').update(content).digest('hex');
    } catch (error) {
      this.logger.error('Hash generation failed', error);
      throw error;
    }
  }

  /**
   * Create blockchain entry for a review
   * @param data - Review data to record
   * @param previousHash - Hash of previous review in chain
   * @returns Blockchain entry with hash
   */
  createBlockchainEntry(
    data: ReviewBlockchainData,
    previousHash: string = this.genesisHash,
  ): BlockchainEntry {
    try {
      const hash = this.generateHash(data, previousHash);

      const entry: BlockchainEntry = {
        reviewId: data.reviewId,
        hash,
        previousHash,
        timestamp: new Date().toISOString(),
        isVerified: false,
      };

      this.logger.log(`Created blockchain entry for review ${data.reviewId} with hash ${hash}`);
      return entry;
    } catch (error) {
      this.logger.error(`Failed to create blockchain entry for review ${data.reviewId}`, error);
      throw error;
    }
  }

  /**
   * Verify a single review's blockchain hash
   * @param data - Review data to verify
   * @param hash - Hash to verify against
   * @param previousHash - Previous hash in chain
   * @returns True if hash is valid
   */
  verifyReviewHash(
    data: ReviewBlockchainData,
    hash: string,
    previousHash: string = this.genesisHash,
  ): boolean {
    try {
      const computedHash = this.generateHash(data, previousHash);
      const isValid = computedHash === hash;

      if (!isValid) {
        this.logger.warn(
          `Hash mismatch for review ${data.reviewId}. Expected: ${computedHash}, Got: ${hash}`,
        );
      }

      return isValid;
    } catch (error) {
      this.logger.error(`Hash verification failed for review ${data.reviewId}`, error);
      return false;
    }
  }

  /**
   * Verify blockchain chain integrity
   * @param entries - All blockchain entries in order
   * @returns Object with validity status and first broken link (if any)
   */
  verifyBlockchainIntegrity(entries: BlockchainEntry[]): {
    isValid: boolean;
    brokenAt?: number;
    message: string;
  } {
    try {
      if (!entries || entries.length === 0) {
        return { isValid: true, message: 'Empty chain is valid' };
      }

      this.logger.log(`Verifying blockchain integrity for ${entries.length} entries`);

      for (let i = 0; i < entries.length; i++) {
        const current = entries[i];

        // For first entry, previousHash should be genesis hash
        if (i === 0) {
          if (current.previousHash !== this.genesisHash) {
            this.logger.error(`Genesis block broken: expected ${this.genesisHash}, got ${current.previousHash}`);
            return {
              isValid: false,
              brokenAt: current.reviewId,
              message: 'Genesis block incorrect',
            };
          }
        } else {
          // For subsequent entries, previousHash should match previous entry's hash
          const previous = entries[i - 1];
          if (current.previousHash !== previous.hash) {
            this.logger.error(
              `Chain broken at review ${current.reviewId}: previous hash mismatch`,
            );
            return {
              isValid: false,
              brokenAt: current.reviewId,
              message: `Chain link broken: expected ${previous.hash}, got ${current.previousHash}`,
            };
          }
        }
      }

      this.logger.log('Blockchain integrity verified successfully');
      return { isValid: true, message: 'Blockchain integrity verified' };
    } catch (error) {
      this.logger.error('Blockchain verification failed', error);
      return { isValid: false, message: `Verification error: ${error.message}` };
    }
  }

  /**
   * Get health status of blockchain service
   */
  getHealth(): { status: string; version: string; timestamp: string } {
    return {
      status: 'healthy',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
    };
  }
}