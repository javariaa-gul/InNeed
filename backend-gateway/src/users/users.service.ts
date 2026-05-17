import {
  ConflictException, Injectable, NotFoundException, UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import * as https from 'https';
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

  private async reverseGeocode(lat: number, lon: number): Promise<{ area?: string; city?: string; country?: string }> {
    return new Promise((resolve) => {
      const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=14&addressdetails=1`;
      const req = https.get(url, { headers: { 'User-Agent': 'ApkaHunarApp/1.0' } }, (res) => {
        let data = '';
        res.on('data', (chunk: Buffer) => data += chunk.toString());
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            const addr = json.address || {};
            const area = addr.suburb || addr.neighbourhood || addr.village || addr.town || addr.county || '';
            const city = addr.city || addr.town || addr.district || addr.county || '';
            const country = addr.country || '';
            resolve({ area, city, country });
          } catch { resolve({}); }
        });
      });
      req.on('error', () => resolve({}));
      req.setTimeout(5000, () => { req.destroy(); resolve({}); });
    });
  }

  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.repo.findOne({ where: { phoneNumber: dto.phoneNumber } });
    if (existing) throw new ConflictException('Phone number already registered.');
    const hashed = await bcrypt.hash(dto.password, 12);

    let resolvedArea = dto.area;
    let resolvedCity = dto.city;
    let resolvedCountry = dto.country;
    if (dto.lat != null && dto.lon != null) {
      const geo = await this.reverseGeocode(dto.lat, dto.lon);
      if (geo.area) resolvedArea = geo.area;
      if (geo.city) resolvedCity = geo.city;
      if (geo.country) resolvedCountry = geo.country;
    }

    const user = this.repo.create({
      ...dto,
      fullName: this.sanitize(dto.fullName),
      password: hashed,
      activeRole: (dto.activeRole as UserRole) ?? UserRole.WORKER,
      area: resolvedArea,
      city: resolvedCity,
      country: resolvedCountry,
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
    // Verify user exists first before marking
    const user = await this.repo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    
    // Mark tutorial as seen (idempotent operation)
    const result = await this.repo.update(id, { tutorialSeen: true });
    
    // Verify the update was successful
    if (result.affected === 0) {
      throw new Error('Failed to update user tutorial status');
    }
  }

  async findAll(): Promise<User[]> { return this.repo.find(); }

  async remove(id: number) { return this.repo.delete(id); }
}
