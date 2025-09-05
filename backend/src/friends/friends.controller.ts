import { Controller, Get, Post, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';

import { FriendsService } from './friends.service';
import { SendFriendRequestDto, RespondToFriendRequestDto, BlockUserDto, FriendshipDto } from './dto/friendship.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Friends')
@Controller('friends')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get()
  @ApiOperation({ summary: 'Get all friends' })
  @ApiResponse({ status: 200, description: 'List of friends', type: [FriendshipDto] })
  async getFriends(@Request() req) {
    return this.friendsService.getFriends(req.user.id);
  }

  @Get('requests')
  @ApiOperation({ summary: 'Get incoming friend requests' })
  @ApiResponse({ status: 200, description: 'List of incoming friend requests', type: [FriendshipDto] })
  async getFriendRequests(@Request() req) {
    return this.friendsService.getFriendRequests(req.user.id);
  }

  @Get('sent')
  @ApiOperation({ summary: 'Get sent friend requests' })
  @ApiResponse({ status: 200, description: 'List of sent friend requests', type: [FriendshipDto] })
  async getSentRequests(@Request() req) {
    return this.friendsService.getSentRequests(req.user.id);
  }

  @Post('requests')
  @ApiOperation({ summary: 'Send friend request' })
  @ApiResponse({ status: 201, description: 'Friend request sent successfully', type: FriendshipDto })
  @ApiResponse({ status: 400, description: 'Bad request' })
  async sendFriendRequest(@Body() dto: SendFriendRequestDto, @Request() req) {
    return this.friendsService.sendFriendRequest(req.user.id, dto);
  }

  @Post('requests/:id/respond')
  @ApiOperation({ summary: 'Respond to friend request' })
  @ApiResponse({ status: 200, description: 'Friend request responded successfully', type: FriendshipDto })
  @ApiResponse({ status: 404, description: 'Friend request not found' })
  async respondToFriendRequest(
    @Param('id') id: string,
    @Body() dto: RespondToFriendRequestDto,
    @Request() req,
  ) {
    return this.friendsService.respondToFriendRequest(req.user.id, +id, dto);
  }

  @Post('block')
  @ApiOperation({ summary: 'Block user' })
  @ApiResponse({ status: 201, description: 'User blocked successfully', type: FriendshipDto })
  @ApiResponse({ status: 400, description: 'Bad request' })
  async blockUser(@Body() dto: BlockUserDto, @Request() req) {
    return this.friendsService.blockUser(req.user.id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove friend' })
  @ApiResponse({ status: 200, description: 'Friend removed successfully' })
  @ApiResponse({ status: 404, description: 'Friendship not found' })
  async removeFriend(@Param('id') id: string, @Request() req) {
    await this.friendsService.removeFriend(req.user.id, +id);
    return { message: 'Friend removed successfully' };
  }
}
