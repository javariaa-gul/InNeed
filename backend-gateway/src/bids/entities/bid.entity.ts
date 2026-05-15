import {
  Entity, Column, PrimaryGeneratedColumn,
  CreateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';
import { Job } from '../../jobs/entities/job.entity.js';

export enum BidStatus {
  PENDING  = 'pending',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  EXPIRED  = 'expired',
}

@Entity('bids')
export class Bid {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  jobId: number;

  @ManyToOne(() => Job, { eager: false, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'jobId' })
  job: Job;

  @Column()
  seekerId: number;

  @ManyToOne(() => User, { eager: true })
  @JoinColumn({ name: 'seekerId' })
  seeker: User;

  @Column({ type: 'float' })
  offeredPrice: number;

  @Column({ type: 'enum', enum: BidStatus, default: BidStatus.PENDING })
  status: BidStatus;

  @Column({ nullable: true, type: 'text' })
  message: string;

  @CreateDateColumn()
  createdAt: Date;
}
