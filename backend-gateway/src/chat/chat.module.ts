import { Module, Controller, Get, Param, UseGuards, Request, ParseIntPipe } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { ChatMessage } from './entities/chat-message.entity.js';
import { ChatGateway } from './gateways/chat.gateway.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { AuthModule } from '../auth/auth.module.js';

@ApiTags('chat')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(
    @InjectRepository(ChatMessage)
    private readonly chatRepo: Repository<ChatMessage>,
  ) {}

  @Get(':jobId/messages')
  async getMessages(
    @Param('jobId', ParseIntPipe) jobId: number,
    @Request() req: any,
  ) {
    const userId = req.user.userId;
    // Only parties of this job can read messages
    const messages = await this.chatRepo.find({
      where: [
        { jobId, senderId: userId },
        { jobId, receiverId: userId },
      ],
      relations: ['sender'],
      order: { createdAt: 'ASC' },
    });
    return messages;
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([ChatMessage]), AuthModule],
  providers: [ChatGateway],
  controllers: [ChatController],
  exports: [ChatGateway],
})
export class ChatModule {}
