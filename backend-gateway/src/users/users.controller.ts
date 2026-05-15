import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UnauthorizedException,
  BadRequestException,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import * as bcrypt from 'bcrypt';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginUserDto } from './dto/login-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  // ─── PUBLIC ──────────────────────────────────────────────────────────────

  @Post('signup')
  @ApiOperation({ summary: 'Register a new user' })
  async signup(@Body() dto: CreateUserDto) {
    const user = await this.usersService.create(dto);
    const token = await this.usersService.generateToken(user);
    const { password, ...result } = user as any;
    return { message: 'Signup successful!', user: result, access_token: token, success: true };
  }

  @Post('login')
  @ApiOperation({ summary: 'Login with phone and password' })
  async login(@Body() dto: LoginUserDto) {
    if (!/^[0-9]{10,11}$/.test(dto.phoneNumber)) {
      throw new BadRequestException('Invalid phone number format');
    }
    const user = await this.usersService.findByPhone(dto.phoneNumber);
    if (!user) throw new UnauthorizedException('Invalid phone number or password');

    const match = await bcrypt.compare(dto.password, user.password);
    if (!match) throw new UnauthorizedException('Invalid phone number or password');

    const token = await this.usersService.generateToken(user);
    const { password, ...result } = user as any;
    return { message: 'Login successful!', user: result, access_token: token, success: true };
  }

  // ─── PROTECTED ───────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Get('me')
  @ApiOperation({ summary: 'Get my profile' })
  async getMyProfile(@Request() req: any) {
    const user = await this.usersService.findOne(req.user.userId);
    const { password, ...result } = user as any;
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Patch('me')
  @ApiOperation({ summary: 'Update my profile' })
  async updateMyProfile(@Request() req: any, @Body() dto: UpdateUserDto) {
    const user = await this.usersService.update(req.user.userId, dto);
    const { password, ...result } = user as any;
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('switch-role')
  @ApiOperation({ summary: 'Switch between Worker and Employer role' })
  async switchRole(@Request() req: any) {
    return await this.usersService.switchRole(req.user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('location')
  @ApiOperation({ summary: 'Update live location' })
  async updateLocation(
    @Request() req: any,
    @Body() body: { lat: number; lon: number },
  ) {
    await this.usersService.updateLocation(req.user.userId, body.lat, body.lon);
    return { success: true };
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('tutorial-seen')
  @ApiOperation({ summary: 'Mark tutorial as seen' })
  async markTutorialSeen(@Request() req: any) {
    await this.usersService.markTutorialSeen(req.user.userId);
    return { success: true };
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Get()
  findAll() {
    return this.usersService.findAll();
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Get(':id')
  async findOne(@Param('id') id: string) {
    const user = await this.usersService.findOne(+id);
    const { password, ...result } = user as any;
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.usersService.remove(+id);
  }
}
