import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum UserRole {
  WORKER = 'worker',
  EMPLOYER = 'employer',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  fullName: string;

  @Column({ unique: true })
  phoneNumber: string;

  @Column()
  password: string;

  // Active role - what the user is currently acting as
  @Column({ type: 'enum', enum: UserRole, default: UserRole.WORKER })
  activeRole: UserRole;

  // Skills (comma-separated) - only relevant for workers
  @Column({ nullable: true, type: 'text' })
  skills: string;

  // Profile info
  @Column({ nullable: true })
  profilePicUrl: string;

  @Column({ nullable: true })
  city: string;

  @Column({ nullable: true })
  area: string;

  @Column({ nullable: true })
  country: string;

  // Live location
  @Column({ nullable: true, type: 'float' })
  lat: number;

  @Column({ nullable: true, type: 'float' })
  lon: number;

  // Ratings (separate for worker and employer roles)
  @Column({ type: 'float', default: 0 })
  workerRating: number;

  @Column({ type: 'int', default: 0 })
  workerRatingCount: number;

  @Column({ type: 'float', default: 0 })
  employerRating: number;

  @Column({ type: 'int', default: 0 })
  employerRatingCount: number;

  // First time tutorial
  @Column({ default: false })
  tutorialSeen: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
