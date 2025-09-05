import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessToken } from 'livekit-server-sdk';
import { GroupsService } from '../groups/groups.service';

@Injectable()
export class VoiceService {
  constructor(
    private configService: ConfigService,
    private groupsService: GroupsService,
  ) {}

  async generateJoinToken(userId: number, groupId: number): Promise<{
    token: string;
    url: string;
    room: string;
  }> {
    // Check if user is member of the group
    const userRole = await this.groupsService.getUserRole(userId, groupId);
    if (!userRole) {
      throw new ForbiddenException('User is not a member of this group');
    }

    const apiKey = this.configService.get('LIVEKIT_API_KEY');
    const apiSecret = this.configService.get('LIVEKIT_API_SECRET');
    const wsUrl = this.configService.get('LIVEKIT_WS_URL');

    if (!apiKey || !apiSecret || !wsUrl) {
      throw new Error('LiveKit configuration missing');
    }

    const roomName = `group-${groupId}`;
    const participantName = `user-${userId}`;

    const token = new AccessToken(apiKey, apiSecret, {
      identity: participantName,
      ttl: '1h', // Token expires in 1 hour
    });

    // Grant permissions based on user role
    token.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      canUpdateOwnMetadata: true,
    });

    // Owners and mods can mute others
    if (['owner', 'mod'].includes(userRole)) {
      token.addGrant({
        room: roomName,
        roomAdmin: true,
      });
    }

    return {
      token: await token.toJwt(),
      url: wsUrl,
      room: roomName,
    };
  }

  async generateRoomToken(groupId: number): Promise<{
    token: string;
    url: string;
    room: string;
  }> {
    const apiKey = this.configService.get('LIVEKIT_API_KEY');
    const apiSecret = this.configService.get('LIVEKIT_API_SECRET');
    const wsUrl = this.configService.get('LIVEKIT_WS_URL');

    if (!apiKey || !apiSecret || !wsUrl) {
      throw new Error('LiveKit configuration missing');
    }

    const roomName = `group-${groupId}`;

    const token = new AccessToken(apiKey, apiSecret, {
      identity: 'room-admin',
      ttl: '24h',
    });

    token.addGrant({
      room: roomName,
      roomJoin: true,
      roomAdmin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      canUpdateOwnMetadata: true,
    });

    return {
      token: await token.toJwt(),
      url: wsUrl,
      room: roomName,
    };
  }
}
