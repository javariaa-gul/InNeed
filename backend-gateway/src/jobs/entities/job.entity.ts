import {
  Entity, Column, PrimaryGeneratedColumn,
  CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

export enum JobStatus {
  OPEN       = 'open',
  ACTIVE     = 'active',
  COMPLETE   = 'complete',
  CANCELLED  = 'cancelled',
}

export enum PricingType {
  FIXED  = 'fixed',
  HOURLY = 'hourly',
}

export enum GenderPreference {
  ANY    = 'any',
  MALE   = 'male',
  FEMALE = 'female',
}

export enum UrgencyLevel {
  URGENT   = 'urgent',
  TODAY    = 'today',
  FLEXIBLE = 'flexible',
}

@Entity('jobs')
export class Job {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  posterId: number;

  @ManyToOne(() => User, { eager: false, nullable: true })
  @JoinColumn({ name: 'posterId' })
  poster: User;

  @Column({ nullable: true })
  acceptedSeekerId?: number;

  @Column()
  title: string;

  @Column({ type: 'text' })
  description: string;

  @Column({ nullable: true })
  skillRequired: string;

  @Column({ type: 'enum', enum: JobStatus, default: JobStatus.OPEN })
  status: JobStatus;

  @Column({ type: 'enum', enum: PricingType, default: PricingType.FIXED })
  pricingType: PricingType;

  @Column({ type: 'float' })
  price: number;

  @Column({ type: 'enum', enum: GenderPreference, default: GenderPreference.ANY })
  genderPreference: GenderPreference;

  @Column({ type: 'enum', enum: UrgencyLevel, default: UrgencyLevel.FLEXIBLE })
  urgency: UrgencyLevel;

  @Column({ nullable: true, type: 'float' })
  locationLat: number;

  @Column({ nullable: true, type: 'float' })
  locationLon: number;

  @Column({ nullable: true })
  locationAddress: string;

  @Column({ default: false })
  isRemote: boolean;

  @Column({ nullable: true, type: 'float' })
  estimatedHours: number;

  @Column({ nullable: true })
  requiredByTime: string;

  @Column({ nullable: true, type: 'text' })
  attachmentUrls: string;

  @Column({ nullable: true, type: 'text' })
  targetedSeekerIds: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
