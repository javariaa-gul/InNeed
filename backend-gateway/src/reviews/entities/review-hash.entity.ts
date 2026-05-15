import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('review_hashes')
export class ReviewHash {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column()
  reviewId!: number;

  @Column({ type: 'text' })
  hash!: string;

  @Column({ type: 'text' })
  previousHash!: string;

  @Column({ default: false })
  isVerified!: boolean;

  @CreateDateColumn()
  createdAt!: Date;
}