import {
  WebSocketGateway, WebSocketServer, SubscribeMessage,
  OnGatewayConnection, OnGatewayDisconnect, MessageBody, ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatMessage } from '../entities/chat-message.entity.js';

@WebSocketGateway({
  origin: '*',
  cors: { origin: '*' },
  namespace: '/ws',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  // userId -> socketId
  private userSockets = new Map<number, string>();

  constructor(
    private readonly jwtService: JwtService,
    @InjectRepository(ChatMessage)
    private readonly chatRepo: Repository<ChatMessage>,
  ) {}

  async handleConnection(client: Socket) {
    try {
      // Accept token from multiple possible places: auth, query (web), or headers
      const token =
        (client.handshake.auth?.token as string) ||
        (client.handshake.query?.token as string) ||
        (client.handshake.headers?.authorization as string)?.replace('Bearer ', '');
      if (!token) { client.disconnect(); return; }
      const payload = this.jwtService.verify(token);
      const uid = typeof payload.sub === 'string' ? Number(payload.sub) : payload.sub;
      client.data.userId = uid;
      this.userSockets.set(uid, client.id);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    if (client.data?.userId) {
      this.userSockets.delete(client.data.userId);
    }
  }

  // Send a message to a specific user by userId
  sendToUser(userId: number, event: string, data: any) {
    const sid = this.userSockets.get(userId);
    if (sid) this.server.to(sid).emit(event, data);
  }

  // Broadcast a job card to multiple seekers
  sendJobCard(seekerIds: number[], jobData: any) {
    for (const id of seekerIds) {
      const sid = this.userSockets.get(id);
      if (sid) this.server.to(sid).emit('new_job_card', jobData);
    }
  }

  @SubscribeMessage('send_message')
  async handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { jobId: number; receiverId: number; message: string },
  ) {
    const senderId = client.data.userId as number;
    if (!senderId || !payload.jobId || !payload.receiverId || !payload.message) return;

    // Persist message
    const msg = this.chatRepo.create({
      jobId: payload.jobId,
      senderId,
      receiverId: payload.receiverId,
      message: payload.message.trim(),
    });
    const saved = await this.chatRepo.save(msg);
    
    // Reload with sender relation to get sender name
    const savedWithSender = await this.chatRepo.findOne({
      where: { id: saved.id },
      relations: ['sender'],
    });

    const outgoing = {
      id: saved.id,
      jobId: saved.jobId,
      senderId,
      senderName: savedWithSender?.sender?.fullName ?? 'User',
      receiverId: payload.receiverId,
      message: saved.message,
      createdAt: saved.createdAt,
    };

    // Echo back to sender
    client.emit('message_received', outgoing);

    // Deliver to receiver if online
    const receiverSid = this.userSockets.get(payload.receiverId);
    if (receiverSid) this.server.to(receiverSid).emit('message_received', outgoing);
  }

  @SubscribeMessage('mark_read')
  async handleMarkRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { jobId: number },
  ) {
    const userId = client.data.userId as number;
    await this.chatRepo.update(
      { jobId: payload.jobId, receiverId: userId, isRead: false },
      { isRead: true },
    );
  }
}
