import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';

import { GroupsService } from './groups.service';
import { CreateGroupDto, UpdateGroupDto, JoinGroupDto, GroupDto } from './dto/group.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Groups')
@Controller('groups')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new group' })
  @ApiResponse({ status: 201, description: 'Group created successfully', type: GroupDto })
  async create(@Body() dto: CreateGroupDto, @Request() req) {
    return this.groupsService.create(req.user.id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all accessible groups' })
  @ApiResponse({ status: 200, description: 'List of groups', type: [GroupDto] })
  async findAll(@Request() req) {
    return this.groupsService.findAll(req.user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get group by ID' })
  @ApiResponse({ status: 200, description: 'Group information', type: GroupDto })
  @ApiResponse({ status: 404, description: 'Group not found' })
  async findOne(@Param('id') id: string, @Request() req) {
    return this.groupsService.findOne(+id, req.user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update group' })
  @ApiResponse({ status: 200, description: 'Group updated successfully', type: GroupDto })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Group not found' })
  async update(@Param('id') id: string, @Body() dto: UpdateGroupDto, @Request() req) {
    return this.groupsService.update(+id, dto, req.user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete group' })
  @ApiResponse({ status: 200, description: 'Group deleted successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Group not found' })
  async remove(@Param('id') id: string, @Request() req) {
    await this.groupsService.remove(+id, req.user.id);
    return { message: 'Group deleted successfully' };
  }

  @Post(':id/join')
  @ApiOperation({ summary: 'Join group' })
  @ApiResponse({ status: 201, description: 'Successfully joined group' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 404, description: 'Group not found' })
  async joinGroup(@Param('id') id: string, @Body() dto: JoinGroupDto, @Request() req) {
    return this.groupsService.joinGroup(req.user.id, { groupId: +id });
  }

  @Post(':id/leave')
  @ApiOperation({ summary: 'Leave group' })
  @ApiResponse({ status: 200, description: 'Successfully left group' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 404, description: 'Group not found' })
  async leaveGroup(@Param('id') id: string, @Request() req) {
    await this.groupsService.leaveGroup(req.user.id, +id);
    return { message: 'Successfully left group' };
  }
}
