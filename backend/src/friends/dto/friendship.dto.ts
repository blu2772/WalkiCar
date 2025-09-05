import { IsNumber, IsNotEmpty, IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SendFriendRequestDto {
  @ApiProperty({ description: 'User ID to send friend request to' })
  @IsNumber()
  @IsNotEmpty()
  userId: number;
}

export class RespondToFriendRequestDto {
  @ApiProperty({ description: 'Response to friend request', enum: ['accept', 'reject'] })
  @IsEnum(['accept', 'reject'])
  @IsNotEmpty()
  action: 'accept' | 'reject';
}

export class BlockUserDto {
  @ApiProperty({ description: 'User ID to block' })
  @IsNumber()
  @IsNotEmpty()
  userId: number;
}

export class FriendshipDto {
  @ApiProperty({ description: 'Friendship ID' })
  id: number;

  @ApiProperty({ description: 'User ID' })
  user_id: number;

  @ApiProperty({ description: 'Friend ID' })
  friend_id: number;

  @ApiProperty({ description: 'Friendship status', enum: ['pending', 'accepted', 'blocked'] })
  status: 'pending' | 'accepted' | 'blocked';

  @ApiProperty({ description: 'Friend user information' })
  friend: {
    id: number;
    display_name: string;
    avatar_url?: string;
  };

  @ApiProperty({ description: 'Created at timestamp' })
  created_at: Date;
}
