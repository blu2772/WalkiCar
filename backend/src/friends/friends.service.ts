import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Friendship } from './entities/friendship.entity';
import { User } from '../users/entities/user.entity';
import { SendFriendRequestDto, RespondToFriendRequestDto, BlockUserDto } from './dto/friendship.dto';

@Injectable()
export class FriendsService {
  constructor(
    @InjectRepository(Friendship)
    private friendshipRepository: Repository<Friendship>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async sendFriendRequest(userId: number, dto: SendFriendRequestDto): Promise<Friendship> {
    const { userId: friendId } = dto;

    if (userId === friendId) {
      throw new BadRequestException('Cannot send friend request to yourself');
    }

    // Check if friend exists
    const friend = await this.userRepository.findOne({ where: { id: friendId } });
    if (!friend) {
      throw new NotFoundException('User not found');
    }

    // Check if friendship already exists
    const existingFriendship = await this.findFriendship(userId, friendId);
    if (existingFriendship) {
      throw new BadRequestException('Friendship already exists');
    }

    // Create friendship request
    const friendship = this.friendshipRepository.create({
      user_id: userId,
      friend_id: friendId,
      status: 'pending',
    });

    return this.friendshipRepository.save(friendship);
  }

  async respondToFriendRequest(userId: number, friendshipId: number, dto: RespondToFriendRequestDto): Promise<Friendship> {
    const friendship = await this.friendshipRepository.findOne({
      where: { id: friendshipId, friend_id: userId },
      relations: ['user', 'friend'],
    });

    if (!friendship) {
      throw new NotFoundException('Friend request not found');
    }

    if (friendship.status !== 'pending') {
      throw new BadRequestException('Friend request already processed');
    }

    if (dto.action === 'accept') {
      friendship.status = 'accepted';
    } else {
      await this.friendshipRepository.remove(friendship);
      return null;
    }

    return this.friendshipRepository.save(friendship);
  }

  async blockUser(userId: number, dto: BlockUserDto): Promise<Friendship> {
    const { userId: friendId } = dto;

    if (userId === friendId) {
      throw new BadRequestException('Cannot block yourself');
    }

    // Check if friendship exists
    let friendship = await this.findFriendship(userId, friendId);
    
    if (!friendship) {
      // Create new blocked friendship
      friendship = this.friendshipRepository.create({
        user_id: userId,
        friend_id: friendId,
        status: 'blocked',
      });
    } else {
      friendship.status = 'blocked';
    }

    return this.friendshipRepository.save(friendship);
  }

  async removeFriend(userId: number, friendId: number): Promise<void> {
    const friendship = await this.findFriendship(userId, friendId);
    
    if (!friendship) {
      throw new NotFoundException('Friendship not found');
    }

    await this.friendshipRepository.remove(friendship);
  }

  async getFriends(userId: number): Promise<Friendship[]> {
    return this.friendshipRepository.find({
      where: [
        { user_id: userId, status: 'accepted' },
        { friend_id: userId, status: 'accepted' },
      ],
      relations: ['user', 'friend'],
    });
  }

  async getFriendRequests(userId: number): Promise<Friendship[]> {
    return this.friendshipRepository.find({
      where: { friend_id: userId, status: 'pending' },
      relations: ['user'],
    });
  }

  async getSentRequests(userId: number): Promise<Friendship[]> {
    return this.friendshipRepository.find({
      where: { user_id: userId, status: 'pending' },
      relations: ['friend'],
    });
  }

  private async findFriendship(userId: number, friendId: number): Promise<Friendship | null> {
    return this.friendshipRepository.findOne({
      where: [
        { user_id: userId, friend_id: friendId },
        { user_id: friendId, friend_id: userId },
      ],
    });
  }
}
