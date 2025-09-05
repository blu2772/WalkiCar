import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { Friendship, FriendshipStatus } from '../users/entities/friendship.entity';
import { CreateFriendshipDto, UpdateFriendshipDto, SearchUsersDto } from './dto/friends.dto';

@Injectable()
export class FriendsService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Friendship)
    private friendshipRepository: Repository<Friendship>,
  ) {}

  async searchUsers(query: string, currentUserId: number): Promise<User[]> {
    return this.userRepository
      .createQueryBuilder('user')
      .where('user.display_name LIKE :query', { query: `%${query}%` })
      .andWhere('user.id != :currentUserId', { currentUserId })
      .limit(20)
      .getMany();
  }

  async getFriends(userId: number): Promise<User[]> {
    const friendships = await this.friendshipRepository.find({
      where: [
        { user_id: userId, status: FriendshipStatus.ACCEPTED },
        { friend_id: userId, status: FriendshipStatus.ACCEPTED },
      ],
      relations: ['user', 'friend'],
    });

    return friendships.map(friendship => 
      friendship.user_id === userId ? friendship.friend : friendship.user
    );
  }

  async getPendingRequests(userId: number): Promise<Friendship[]> {
    return this.friendshipRepository.find({
      where: { friend_id: userId, status: FriendshipStatus.PENDING },
      relations: ['user'],
    });
  }

  async sendFriendRequest(fromUserId: number, toUserId: number): Promise<Friendship> {
    if (fromUserId === toUserId) {
      throw new BadRequestException('Cannot send friend request to yourself');
    }

    // Check if friendship already exists
    const existingFriendship = await this.friendshipRepository.findOne({
      where: [
        { user_id: fromUserId, friend_id: toUserId },
        { user_id: toUserId, friend_id: fromUserId },
      ],
    });

    if (existingFriendship) {
      throw new BadRequestException('Friendship already exists');
    }

    const friendship = this.friendshipRepository.create({
      user_id: fromUserId,
      friend_id: toUserId,
      status: FriendshipStatus.PENDING,
    });

    return this.friendshipRepository.save(friendship);
  }

  async acceptFriendRequest(friendshipId: number, userId: number): Promise<Friendship> {
    const friendship = await this.friendshipRepository.findOne({
      where: { id: friendshipId, friend_id: userId, status: FriendshipStatus.PENDING },
    });

    if (!friendship) {
      throw new NotFoundException('Friend request not found');
    }

    friendship.status = FriendshipStatus.ACCEPTED;
    return this.friendshipRepository.save(friendship);
  }

  async rejectFriendRequest(friendshipId: number, userId: number): Promise<void> {
    const friendship = await this.friendshipRepository.findOne({
      where: { id: friendshipId, friend_id: userId, status: FriendshipStatus.PENDING },
    });

    if (!friendship) {
      throw new NotFoundException('Friend request not found');
    }

    await this.friendshipRepository.remove(friendship);
  }

  async blockUser(userId: number, friendId: number): Promise<Friendship> {
    const friendship = await this.friendshipRepository.findOne({
      where: [
        { user_id: userId, friend_id: friendId },
        { user_id: friendId, friend_id: userId },
      ],
    });

    if (friendship) {
      friendship.status = FriendshipStatus.BLOCKED;
      return this.friendshipRepository.save(friendship);
    } else {
      const newFriendship = this.friendshipRepository.create({
        user_id: userId,
        friend_id: friendId,
        status: FriendshipStatus.BLOCKED,
      });
      return this.friendshipRepository.save(newFriendship);
    }
  }

  async removeFriend(userId: number, friendId: number): Promise<void> {
    const friendship = await this.friendshipRepository.findOne({
      where: [
        { user_id: userId, friend_id: friendId },
        { user_id: friendId, friend_id: userId },
      ],
    });

    if (!friendship) {
      throw new NotFoundException('Friendship not found');
    }

    await this.friendshipRepository.remove(friendship);
  }
}
