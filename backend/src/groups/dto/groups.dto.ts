import { IsString, IsBoolean, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateGroupDto {
  @ApiProperty({ description: 'Group name' })
  @IsString()
  name: string;

  @ApiPropertyOptional({ description: 'Group description' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ description: 'Whether the group is public' })
  @IsOptional()
  @IsBoolean()
  is_public?: boolean;
}

export class UpdateGroupDto {
  @ApiPropertyOptional({ description: 'Group name' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ description: 'Group description' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ description: 'Whether the group is public' })
  @IsOptional()
  @IsBoolean()
  is_public?: boolean;
}

export class JoinGroupDto {
  @ApiProperty({ description: 'Group ID to join' })
  @IsString()
  groupId: string;
}
