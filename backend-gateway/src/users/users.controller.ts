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
  UseInterceptors,
  UploadedFile,
  Logger,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import * as bcrypt from 'bcrypt';
import { UsersService } from './users.service';
import { CloudinaryService } from '../cloudinary/cloudinary.service';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginUserDto } from './dto/login-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('users')
@Controller('users')
export class UsersController {
  private readonly logger = new Logger(UsersController.name);

  constructor(
    private readonly usersService: UsersService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  // ─────────────────────────────────────────────────────────────────
  // PUBLIC ENDPOINTS
  // ─────────────────────────────────────────────────────────────────

  @Post('signup')
  @ApiOperation({ summary: 'Register a new user' })
  async signup(@Body() dto: CreateUserDto) {
    this.logger.log(`[Signup] New user registration: phone=${dto.phoneNumber}`);

    const user = await this.usersService.create(dto);
    const token = await this.usersService.generateToken(user);
    const { password, ...result } = user as any;

    return {
      message: 'Signup successful!',
      user: result,
      access_token: token,
      success: true,
    };
  }

  @Post('login')
  @ApiOperation({ summary: 'Login with phone and password' })
  async login(@Body() dto: LoginUserDto) {
    if (!/^[0-9]{10,11}$/.test(dto.phoneNumber)) {
      throw new BadRequestException('Invalid phone number format');
    }

    this.logger.log(`[Login] Attempting login for phone=${dto.phoneNumber}`);

    const user = await this.usersService.findByPhone(dto.phoneNumber);
    if (!user) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    const match = await bcrypt.compare(dto.password, user.password);
    if (!match) {
      throw new UnauthorizedException('Invalid phone number or password');
    }

    const token = await this.usersService.generateToken(user);
    const { password, ...result } = user as any;

    this.logger.log(`[Login] Successful login for userId=${user.id}`);

    return {
      message: 'Login successful!',
      user: result,
      access_token: token,
      success: true,
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // PROTECTED ENDPOINTS
  // ─────────────────────────────────────────────────────────────────

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
    this.logger.log(`[Update Profile] userId=${req.user.userId}`);

    const user = await this.usersService.update(req.user.userId, dto);
    const { password, ...result } = user as any;
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('me/avatar')
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage() }))
  @ApiOperation({ summary: 'Upload/change profile avatar' })
  async uploadAvatar(@Request() req: any, @UploadedFile() file: Express.Multer.File) {
    try {
      this.logger.log(`[Upload Avatar] userId=${req.user.userId}, file=${file?.originalname}`);

      if (!file) {
        throw new BadRequestException('Image file is required');
      }

      // Validate file type
      const isImageMime = file.mimetype?.startsWith('image/');
      const isImageName = /\.(jpg|jpeg|png|gif|webp|bmp|heic|heif)$/i.test(
        file.originalname ?? '',
      );
      if (!isImageMime && !isImageName) {
        throw new BadRequestException('File must be an image');
      }

      // Validate file size (5MB max)
      const MAX_FILE_SIZE = 5 * 1024 * 1024;
      if (file.size > MAX_FILE_SIZE) {
        throw new BadRequestException('Image size exceeds 5MB limit');
      }

      // Upload to Cloudinary
      this.logger.log(`[Upload Avatar] Uploading image to Cloudinary (${file.size} bytes)`);

      const url = await this.cloudinaryService.uploadImage(file, 'apka-hunar/avatars');

      this.logger.log(`[Upload Avatar] Cloud URL: ${url}`);

      // Update user avatar in database
      await this.usersService.update(req.user.userId, { avatarUrl: url } as any);

      const user = await this.usersService.findOne(req.user.userId);
      const { password, ...result } = user as any;

      this.logger.log(`[Upload Avatar] Avatar updated successfully for userId=${req.user.userId}`);

      return {
        success: true,
        message: 'Avatar uploaded successfully',
        avatarUrl: url,
        user: result,
      };
    } catch (error) {
      this.logger.error('[Upload Avatar] Error:', error);
      throw error;
    }
  }

  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @Post('switch-role')
  @ApiOperation({ summary: 'Switch between Worker and Employer role' })
  async switchRole(@Request() req: any) {
    this.logger.log(`[Switch Role] userId=${req.user.userId}`);
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
  @ApiOperation({ summary: 'Mark tutorial as seen by the authenticated user' })
  async markTutorialSeen(@Request() req: any) {
    try {
      await this.usersService.markTutorialSeen(req.user.userId);
      return {
        success: true,
        message: 'Tutorial marked as seen',
      };
    } catch (error) {
      this.logger.error('[Mark Tutorial Seen] Error:', error);
      throw error;
    }
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
