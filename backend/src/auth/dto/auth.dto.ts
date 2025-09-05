import { IsString, IsNotEmpty, IsEmail, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class AppleSignInDto {
  @ApiProperty({ description: 'Apple identity token' })
  @IsString()
  @IsNotEmpty()
  identityToken: string;

  @ApiProperty({ description: 'Apple authorization code' })
  @IsString()
  @IsNotEmpty()
  authorizationCode: string;

  @ApiProperty({ description: 'User email from Apple' })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiProperty({ description: 'User full name from Apple' })
  @IsString()
  @IsOptional()
  fullName?: string;
}

export class RefreshTokenDto {
  @ApiProperty({ description: 'Refresh token' })
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class AuthResponseDto {
  @ApiProperty({ description: 'JWT access token' })
  accessToken: string;

  @ApiProperty({ description: 'JWT refresh token' })
  refreshToken: string;

  @ApiProperty({ description: 'User information' })
  user: {
    id: number;
    appleSub: string;
    displayName: string;
    avatarUrl?: string;
  };
}
