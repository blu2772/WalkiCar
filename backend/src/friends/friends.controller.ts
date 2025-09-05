import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { FriendsService } from './friends.service';
import { CreateFriendshipDto, UpdateFriendshipDto, SearchUsersDto } from './dto/friends.dto';

@ApiTags('Friends')
@Controller('friends')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get('search')
  @ApiOperation({ summary: 'Search for users' })
  @ApiResponse({ status: 200, description: 'List of users matching search query' })
  async searchUsers(@Query() query: SearchUsersDto, @Request() req) {
    return this.friendsService.searchUsers(query.query, req.user.id);
  }

  @Get()
  @ApiOperation({ summary: 'Get user friends' })
  @ApiResponse({ status: 200, description: 'List of friends' })
  async getFriends(@Request() req) {
    return this.friendsService.getFriends(req.user.id);
  }

  @Get('requests')
  @ApiOperation({ summary: 'Get pending friend requests' })
  @ApiResponse({ status: 200, description: 'List of pending friend requests' })
  async getPendingRequests(@Request() req) {
    return this.friendsService.getPendingRequests(req.user.id);
  }

  @Post('requests')
  @ApiOperation({ summary: 'Send friend request' })
  @ApiResponse({ status: 201, description: 'Friend request sent successfully' })
  async sendFriendRequest(@Body() createFriendshipDto: CreateFriendshipDto, @Request() req) {
    return this.friendsService.sendFriendRequest(req.user.id, createFriendshipDto.userId);
  }

  @Patch('requests/:id/accept')
  @ApiOperation({ summary: 'Accept friend request' })
  @ApiResponse({ status: 200, description: 'Friend request accepted' })
  async acceptFriendRequest(@Param('id') id: string, @Request() req) {
    return this.friendsService.acceptFriendRequest(parseInt(id), req.user.id);
  }

  @Patch('requests/:id/reject')
  @ApiOperation({ summary: 'Reject friend request' })
  @ApiResponse({ status: 200, description: 'Friend request rejected' })
  async rejectFriendRequest(@Param('id') id: string, @Request() req) {
    return this.friendsService.rejectFriendRequest(parseInt(id), req.user.id);
  }

  @Post(':id/block')
  @ApiOperation({ summary: 'Block user' })
  @ApiResponse({ status: 200, description: 'User blocked successfully' })
  async blockUser(@Param('id') id: string, @Request() req) {
    return this.friendsService.blockUser(req.user.id, parseInt(id));
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove friend' })
  @ApiResponse({ status: 200, description: 'Friend removed successfully' })
  async removeFriend(@Param('id') id: string, @Request() req) {
    return this.friendsService.removeFriend(req.user.id, parseInt(id));
  }
}
