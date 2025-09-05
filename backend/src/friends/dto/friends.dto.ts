import { IsString, IsNumber, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SearchUsersDto {
  @ApiProperty({ description: 'Search query for user names' })
  @IsString()
  query: string;
}

export class CreateFriendshipDto {
  @ApiProperty({ description: 'User ID to send friend request to' })
  @IsNumber()
  userId: number;
}

export class UpdateFriendshipDto {
  @ApiPropertyOptional({ description: 'Friendship status' })
  @IsOptional()
  @IsString()
  status?: string;
}
