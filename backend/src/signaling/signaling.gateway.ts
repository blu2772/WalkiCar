import { Injectable, Logger } from '@nestjs/common';
import { WebSocketGateway, WebSocketServer, SubscribeMessage, MessageBody, ConnectedSocket, OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';

interface SignalingMessage {
  type: 'offer' | 'answer' | 'ice-candidate' | 'join' | 'leave' | 'mute' | 'unmute';
  data?: any;
  targetUserId?: string;
  groupId?: string;
}

interface RoomParticipant {
  userId: string;
  socketId: string;
  isMuted: boolean;
}

@Injectable()
@WebSocketGateway({
  cors: {
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    credentials: true,
  },
  namespace: '/voice',
})
export class SignalingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(SignalingGateway.name);
  private rooms = new Map<string, Map<string, RoomParticipant>>();

  constructor(private jwtService: JwtService) {}

  async handleConnection(client: Socket) {
    try {
      // Verify JWT token from handshake
      const token = client.handshake.auth.token;
      if (!token) {
        this.logger.warn('Client connected without token');
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify(token);
      const userId = payload.sub;
      
      client.data.userId = userId;
      this.logger.log(`Client connected: ${userId} (${client.id})`);
      
      // Send TURN server configuration
      client.emit('turn-config', {
        uris: [process.env.TURN_URI || 'turn:localhost:3478'],
        username: process.env.TURN_USERNAME || 'turnuser',
        credential: process.env.TURN_PASSWORD || 'turnpassword',
      });

    } catch (error) {
      this.logger.error('Authentication failed:', error);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data.userId;
    this.logger.log(`Client disconnected: ${userId} (${client.id})`);
    
    // Remove from all rooms
    this.rooms.forEach((participants, roomId) => {
      if (participants.has(userId)) {
        participants.delete(userId);
        this.server.to(roomId).emit('participant-left', { userId });
        
        // Clean up empty rooms
        if (participants.size === 0) {
          this.rooms.delete(roomId);
        }
      }
    });
  }

  @SubscribeMessage('join-room')
  handleJoinRoom(
    @MessageBody() data: { groupId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    const { groupId } = data;
    
    // Leave previous rooms
    client.rooms.forEach(room => {
      if (room !== client.id) {
        client.leave(room);
        this.removeParticipantFromRoom(room, userId);
      }
    });
    
    // Join new room
    client.join(groupId);
    
    // Initialize room if it doesn't exist
    if (!this.rooms.has(groupId)) {
      this.rooms.set(groupId, new Map());
    }
    
    const participants = this.rooms.get(groupId);
    participants.set(userId, {
      userId,
      socketId: client.id,
      isMuted: true,
    });
    
    this.logger.log(`User ${userId} joined room ${groupId}`);
    
    // Notify other participants
    client.to(groupId).emit('participant-joined', { userId });
    
    // Send current participants to the new user
    const participantList = Array.from(participants.values()).map(p => ({
      userId: p.userId,
      isMuted: p.isMuted,
    }));
    client.emit('participants-list', participantList);
  }

  @SubscribeMessage('leave-room')
  handleLeaveRoom(
    @MessageBody() data: { groupId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    const { groupId } = data;
    
    client.leave(groupId);
    this.removeParticipantFromRoom(groupId, userId);
    
    this.logger.log(`User ${userId} left room ${groupId}`);
    client.to(groupId).emit('participant-left', { userId });
  }

  @SubscribeMessage('webrtc-signaling')
  handleWebRTCSignaling(
    @MessageBody() message: SignalingMessage,
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    const { type, data, targetUserId } = message;
    
    this.logger.debug(`WebRTC signaling: ${type} from ${userId} to ${targetUserId}`);
    
    // Forward signaling message to target user
    if (targetUserId) {
      const targetParticipant = this.findParticipantByUserId(targetUserId);
      if (targetParticipant) {
        this.server.to(targetParticipant.socketId).emit('webrtc-signaling', {
          type,
          data,
          fromUserId: userId,
        });
      }
    }
  }

  @SubscribeMessage('mute')
  handleMute(
    @MessageBody() data: { groupId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    const { groupId } = data;
    
    const participants = this.rooms.get(groupId);
    if (participants && participants.has(userId)) {
      participants.get(userId).isMuted = true;
      this.logger.log(`User ${userId} muted in room ${groupId}`);
      
      client.to(groupId).emit('participant-muted', { userId });
    }
  }

  @SubscribeMessage('unmute')
  handleUnmute(
    @MessageBody() data: { groupId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    const { groupId } = data;
    
    const participants = this.rooms.get(groupId);
    if (participants && participants.has(userId)) {
      participants.get(userId).isMuted = false;
      this.logger.log(`User ${userId} unmuted in room ${groupId}`);
      
      client.to(groupId).emit('participant-unmuted', { userId });
    }
  }

  private removeParticipantFromRoom(roomId: string, userId: string) {
    const participants = this.rooms.get(roomId);
    if (participants) {
      participants.delete(userId);
      
      // Clean up empty rooms
      if (participants.size === 0) {
        this.rooms.delete(roomId);
      }
    }
  }

  private findParticipantByUserId(userId: string): RoomParticipant | null {
    for (const participants of this.rooms.values()) {
      if (participants.has(userId)) {
        return participants.get(userId);
      }
    }
    return null;
  }

  // Get room statistics for monitoring
  getRoomStats() {
    const stats = {};
    this.rooms.forEach((participants, roomId) => {
      stats[roomId] = {
        participantCount: participants.size,
        participants: Array.from(participants.keys()),
      };
    });
    return stats;
  }
}
