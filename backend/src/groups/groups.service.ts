import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Group } from '../users/entities/group.entity';
import { GroupMember, GroupRole } from '../users/entities/group-member.entity';
import { User } from '../users/entities/user.entity';
import { CreateGroupDto, UpdateGroupDto, JoinGroupDto } from './dto/groups.dto';

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

  async createGroup(createGroupDto: CreateGroupDto, ownerId: number): Promise<Group> {
    const group = this.groupRepository.create({
      ...createGroupDto,
      owner_id: ownerId,
    });

    const savedGroup = await this.groupRepository.save(group);

    // Add owner as member
    const ownerMember = this.groupMemberRepository.create({
      group_id: savedGroup.id,
      user_id: ownerId,
      role: GroupRole.OWNER,
    });
    await this.groupMemberRepository.save(ownerMember);

    return savedGroup;
  }

  async getGroups(userId: number): Promise<Group[]> {
    // Get groups where user is a member
    const userGroups = await this.groupRepository
      .createQueryBuilder('group')
      .leftJoin('group.members', 'member')
      .where('member.user_id = :userId', { userId })
      .getMany();

    // Get public groups
    const publicGroups = await this.groupRepository.find({
      where: { is_public: true },
    });

    // Combine and deduplicate
    const allGroups = [...userGroups];
    publicGroups.forEach(publicGroup => {
      if (!allGroups.find(g => g.id === publicGroup.id)) {
        allGroups.push(publicGroup);
      }
    });

    return allGroups;
  }

  async getGroupById(groupId: number, userId: number): Promise<Group> {
    const group = await this.groupRepository.findOne({
      where: { id: groupId },
      relations: ['members', 'members.user'],
    });

    if (!group) {
      throw new NotFoundException('Group not found');
    }

    // Check if user has access to the group
    const isMember = group.members.some(member => member.user_id === userId);
    if (!group.is_public && !isMember) {
      throw new ForbiddenException('Access denied to private group');
    }

    return group;
  }

  async joinGroup(groupId: number, userId: number): Promise<GroupMember> {
    const group = await this.groupRepository.findOne({
      where: { id: groupId },
    });

    if (!group) {
      throw new NotFoundException('Group not found');
    }

    // Check if user is already a member
    const existingMember = await this.groupMemberRepository.findOne({
      where: { group_id: groupId, user_id: userId },
    });

    if (existingMember) {
      throw new ForbiddenException('User is already a member of this group');
    }

    const member = this.groupMemberRepository.create({
      group_id: groupId,
      user_id: userId,
      role: GroupRole.MEMBER,
    });

    return this.groupMemberRepository.save(member);
  }

  async leaveGroup(groupId: number, userId: number): Promise<void> {
    const member = await this.groupMemberRepository.findOne({
      where: { group_id: groupId, user_id: userId },
    });

    if (!member) {
      throw new NotFoundException('User is not a member of this group');
    }

    // Check if user is the owner
    if (member.role === GroupRole.OWNER) {
      throw new ForbiddenException('Group owner cannot leave the group');
    }

    await this.groupMemberRepository.remove(member);
  }

  async updateGroup(groupId: number, updateGroupDto: UpdateGroupDto, userId: number): Promise<Group> {
    const group = await this.groupRepository.findOne({
      where: { id: groupId },
      relations: ['members'],
    });

    if (!group) {
      throw new NotFoundException('Group not found');
    }

    // Check if user is the owner
    const isOwner = group.members.some(member => 
      member.user_id === userId && member.role === GroupRole.OWNER
    );

    if (!isOwner) {
      throw new ForbiddenException('Only group owner can update the group');
    }

    Object.assign(group, updateGroupDto);
    return this.groupRepository.save(group);
  }

  async deleteGroup(groupId: number, userId: number): Promise<void> {
    const group = await this.groupRepository.findOne({
      where: { id: groupId },
      relations: ['members'],
    });

    if (!group) {
      throw new NotFoundException('Group not found');
    }

    // Check if user is the owner
    const isOwner = group.members.some(member => 
      member.user_id === userId && member.role === GroupRole.OWNER
    );

    if (!isOwner) {
      throw new ForbiddenException('Only group owner can delete the group');
    }

    await this.groupRepository.remove(group);
  }
}
