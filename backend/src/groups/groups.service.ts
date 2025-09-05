import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Group } from './entities/group.entity';
import { GroupMember } from './entities/group-member.entity';
import { User } from '../users/entities/user.entity';
import { CreateGroupDto, UpdateGroupDto, JoinGroupDto } from './dto/group.dto';

@Injectable()
export class GroupsService {
  constructor(
    @InjectRepository(Group)
    private groupRepository: Repository<Group>,
    @InjectRepository(GroupMember)
    private groupMemberRepository: Repository<GroupMember>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async create(userId: number, dto: CreateGroupDto): Promise<Group> {
    const group = this.groupRepository.create({
      owner_id: userId,
      name: dto.name,
      description: dto.description,
      is_public: dto.is_public || false,
    });

    const savedGroup = await this.groupRepository.save(group);

    // Add owner as member
    await this.groupMemberRepository.save({
      group_id: savedGroup.id,
      user_id: userId,
      role: 'owner',
    });

    return savedGroup;
  }

  async findAll(userId: number): Promise<Group[]> {
    // Get groups where user is member or public groups
    return this.groupRepository
      .createQueryBuilder('group')
      .leftJoin('group.groupMembers', 'member', 'member.user_id = :userId', { userId })
      .where('group.is_public = true OR member.user_id = :userId', { userId })
      .leftJoinAndSelect('group.owner', 'owner')
      .leftJoinAndSelect('group.groupMembers', 'groupMembers')
      .leftJoinAndSelect('groupMembers.user', 'memberUser')
      .getMany();
  }

  async findOne(id: number, userId: number): Promise<Group> {
    const group = await this.groupRepository.findOne({
      where: { id },
      relations: ['owner', 'groupMembers', 'groupMembers.user'],
    });

    if (!group) {
      throw new NotFoundException('Group not found');
    }

    // Check if user can access this group
    const isMember = group.groupMembers.some(member => member.user_id === userId);
    if (!group.is_public && !isMember) {
      throw new ForbiddenException('Access denied to private group');
    }

    return group;
  }

  async update(id: number, dto: UpdateGroupDto, userId: number): Promise<Group> {
    const group = await this.findOne(id, userId);
    
    // Check if user is owner or mod
    const member = group.groupMembers.find(m => m.user_id === userId);
    if (!member || !['owner', 'mod'].includes(member.role)) {
      throw new ForbiddenException('Only owners and moderators can update group');
    }

    Object.assign(group, dto);
    return this.groupRepository.save(group);
  }

  async remove(id: number, userId: number): Promise<void> {
    const group = await this.findOne(id, userId);
    
    // Only owner can delete group
    const member = group.groupMembers.find(m => m.user_id === userId);
    if (!member || member.role !== 'owner') {
      throw new ForbiddenException('Only group owner can delete group');
    }

    await this.groupRepository.remove(group);
  }

  async joinGroup(userId: number, dto: JoinGroupDto): Promise<GroupMember> {
    const group = await this.groupRepository.findOne({ where: { id: dto.groupId } });
    
    if (!group) {
      throw new NotFoundException('Group not found');
    }

    // Check if user is already a member
    const existingMember = await this.groupMemberRepository.findOne({
      where: { group_id: dto.groupId, user_id: userId },
    });

    if (existingMember) {
      throw new BadRequestException('User is already a member of this group');
    }

    // Add user as member
    const member = this.groupMemberRepository.create({
      group_id: dto.groupId,
      user_id: userId,
      role: 'member',
    });

    return this.groupMemberRepository.save(member);
  }

  async leaveGroup(userId: number, groupId: number): Promise<void> {
    const member = await this.groupMemberRepository.findOne({
      where: { group_id: groupId, user_id: userId },
    });

    if (!member) {
      throw new NotFoundException('User is not a member of this group');
    }

    // Owner cannot leave group (must delete it instead)
    if (member.role === 'owner') {
      throw new BadRequestException('Group owner cannot leave group. Delete the group instead.');
    }

    await this.groupMemberRepository.remove(member);
  }

  async getUserRole(userId: number, groupId: number): Promise<'owner' | 'mod' | 'member' | null> {
    const member = await this.groupMemberRepository.findOne({
      where: { group_id: groupId, user_id: userId },
    });

    return member ? member.role : null;
  }
}
