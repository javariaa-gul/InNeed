import {
  Entity, Column, PrimaryGeneratedColumn,
  CreateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity.js';

@Entity('reviews')
export class Review {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  jobId!: number;

  @Column()
  reviewerId!: number;

  @ManyToOne(() => User, { eager: true })
  @JoinColumn({ name: 'reviewerId' })
  reviewer!: User;

  @Column()
  revieweeId!: number;

  @ManyToOne(() => User, { eager: false })
  @JoinColumn({ name: 'revieweeId' })
  reviewee!: User;

  @Column()
  revieweeRole!: string;

  @Column({ type: 'int' })
  overallRating!: number;

  @Column({ type: 'int', nullable: true })
  workQualityRating!: number;

  @Column({ type: 'int', nullable: true })
  behaviorRating!: number;

  @Column({ type: 'int', nullable: true })
  smoothnessRating!: number;

  @Column({ nullable: true, type: 'text' })
  comment!: string;

  @Column({ type: 'simple-array', nullable: true, default: '' })
  imageUrls!: string[];

  @Column({ nullable: true })
  blockchainHash!: string;

  @CreateDateColumn()
  createdAt!: Date;
}