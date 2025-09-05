import { IsString, IsNotEmpty, IsOptional, IsBoolean, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateGroupDto {
  @ApiProperty({ description: 'Group name', minLength: 1, maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @Length(1, 100)
  name: string;

  @ApiProperty({ description: 'Group description', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ description: 'Is group public', required: false, default: false })
  @IsBoolean()
  @IsOptional()
  is_public?: boolean;
}

export class UpdateGroupDto {
  @ApiProperty({ description: 'Group name', minLength: 1, maxLength: 100, required: false })
  @IsString()
  @IsOptional()
  @Length(1, 100)
  name?: string;

  @ApiProperty({ description: 'Group description', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ description: 'Is group public', required: false })
  @IsBoolean()
  @IsOptional()
  is_public?: boolean;
}

export class JoinGroupDto {
  @ApiProperty({ description: 'Group ID to join' })
  @IsNotEmpty()
  groupId: number;
}

export class GroupDto {
  @ApiProperty({ description: 'Group ID' })
  id: number;

  @ApiProperty({ description: 'Group name' })
  name: string;

  @ApiProperty({ description: 'Group description' })
  description: string;

  @ApiProperty({ description: 'Is group public' })
  is_public: boolean;

  @ApiProperty({ description: 'Group owner information' })
  owner: {
    id: number;
    display_name: string;
    avatar_url?: string;
  };

  @ApiProperty({ description: 'User role in group' })
  userRole: 'owner' | 'mod' | 'member' | null;

  @ApiProperty({ description: 'Member count' })
  memberCount: number;

  @ApiProperty({ description: 'Created at timestamp' })
  created_at: Date;
}

export class VoiceTokenDto {
  @ApiProperty({ description: 'LiveKit join token' })
  token: string;

  @ApiProperty({ description: 'LiveKit WebSocket URL' })
  url: string;

  @ApiProperty({ description: 'Room name' })
  room: string;
}
