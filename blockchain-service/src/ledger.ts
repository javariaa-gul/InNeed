import * as crypto from 'crypto';

export interface ReviewData {
  reviewId: number;
  jobId: number;
  reviewerId: number;
  revieweeId: number;
  overallRating: number;
  comment: string;
  imageUrls: string[];
  createdAt: string;
}

export interface LedgerEntry {
  reviewId: number;
  hash: string;
  previousHash: string;
  timestamp: string;
}

// In-memory ledger (append-only)
const ledger: LedgerEntry[] = [];

export function generateHash(data: ReviewData, previousHash: string): string {
  const content = JSON.stringify({
    reviewId: data.reviewId,
    jobId: data.jobId,
    reviewerId: data.reviewerId,
    revieweeId: data.revieweeId,
    overallRating: data.overallRating,
    comment: data.comment,
    imageUrls: data.imageUrls,
    createdAt: data.createdAt,
    previousHash,
  });
  return crypto.createHash('sha256').update(content).digest('hex');
}

export function addToLedger(data: ReviewData): LedgerEntry {
  const previousHash = ledger.length > 0
    ? ledger[ledger.length - 1].hash
    : '0000000000000000';

  const hash = generateHash(data, previousHash);

  const entry: LedgerEntry = {
    reviewId: data.reviewId,
    hash,
    previousHash,
    timestamp: new Date().toISOString(),
  };

  ledger.push(entry);
  return entry;
}

export function verifyReview(reviewId: number, hash: string): boolean {
  const entry = ledger.find(e => e.reviewId === reviewId);
  if (!entry) return false;
  return entry.hash === hash;
}

export function getLedger(): LedgerEntry[] {
  return ledger;
}