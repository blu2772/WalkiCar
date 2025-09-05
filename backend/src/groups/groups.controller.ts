import { Controller, Get, Post, Patch, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { GroupsService } from './groups.service';
import { CreateGroupDto, UpdateGroupDto, JoinGroupDto } from './dto/groups.dto';

@ApiTags('Groups')
@Controller('groups')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new group' })
  @ApiResponse({ status: 201, description: 'Group created successfully' })
  async createGroup(@Body() createGroupDto: CreateGroupDto, @Request() req) {
    return this.groupsService.createGroup(createGroupDto, req.user.id);
  }

  @Get()
  @ApiOperation({ summary: 'Get user groups and public groups' })
  @ApiResponse({ status: 200, description: 'List of groups' })
  async getGroups(@Request() req) {
    return this.groupsService.getGroups(req.user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get group by ID' })
  @ApiResponse({ status: 200, description: 'Group details' })
  async getGroupById(@Param('id') id: string, @Request() req) {
    return this.groupsService.getGroupById(parseInt(id), req.user.id);
  }

  @Post(':id/join')
  @ApiOperation({ summary: 'Join a group' })
  @ApiResponse({ status: 201, description: 'Successfully joined group' })
  async joinGroup(@Param('id') id: string, @Request() req) {
    return this.groupsService.joinGroup(parseInt(id), req.user.id);
  }

  @Post(':id/leave')
  @ApiOperation({ summary: 'Leave a group' })
  @ApiResponse({ status: 200, description: 'Successfully left group' })
  async leaveGroup(@Param('id') id: string, @Request() req) {
    return this.groupsService.leaveGroup(parseInt(id), req.user.id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update group' })
  @ApiResponse({ status: 200, description: 'Group updated successfully' })
  async updateGroup(@Param('id') id: string, @Body() updateGroupDto: UpdateGroupDto, @Request() req) {
    return this.groupsService.updateGroup(parseInt(id), updateGroupDto, req.user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete group' })
  @ApiResponse({ status: 200, description: 'Group deleted successfully' })
  async deleteGroup(@Param('id') id: string, @Request() req) {
    return this.groupsService.deleteGroup(parseInt(id), req.user.id);
  }
}
