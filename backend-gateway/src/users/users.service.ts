import {
  ConflictException, Injectable, NotFoundException, UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { CreateUserDto } from './dto/create-user.dto.js';
import { UpdateUserDto } from './dto/update-user.dto.js';
import { User, UserRole } from './entities/user.entity.js';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly repo: Repository<User>,
    private readonly jwtService: JwtService,
  ) {}

  private sanitize(s: string): string {
    return (s ?? '').trim().replace(/[<>"']/g, '');
  }

  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.repo.findOne({ where: { phoneNumber: dto.phoneNumber } });
    if (existing) throw new ConflictException('Phone number already registered.');
    const hashed = await bcrypt.hash(dto.password, 12);
    const user = this.repo.create({
      ...dto,
      fullName: this.sanitize(dto.fullName),
      password: hashed,
      activeRole: (dto.activeRole as UserRole) ?? UserRole.WORKER,
    });
    return this.repo.save(user);
  }

  async findByPhone(phoneNumber: string): Promise<User | null> {
    return this.repo.findOne({ where: { phoneNumber } });
  }

  generateToken(user: User): string {
    return this.jwtService.sign({
      sub: user.id,
      phoneNumber: user.phoneNumber,
      role: user.activeRole,
    });
  }

  async findOne(id: number): Promise<User> {
    const user = await this.repo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async update(id: number, dto: UpdateUserDto): Promise<User> {
    if (dto.fullName) dto.fullName = this.sanitize(dto.fullName);
    await this.repo.update(id, dto);
    return this.findOne(id);
  }

  async switchRole(id: number): Promise<{ activeRole: UserRole; token: string }> {
    const user = await this.findOne(id);
    user.activeRole = user.activeRole === UserRole.WORKER ? UserRole.EMPLOYER : UserRole.WORKER;
    await this.repo.save(user);
    return { activeRole: user.activeRole, token: this.generateToken(user) };
  }

  async updateLocation(id: number, lat: number, lon: number): Promise<void> {
    await this.repo.update(id, { lat, lon });
  }

  async markTutorialSeen(id: number): Promise<void> {
    await this.repo.update(id, { tutorialSeen: true });
  }

  async findAll(): Promise<User[]> { return this.repo.find(); }

  async remove(id: number) { return this.repo.delete(id); }
}
