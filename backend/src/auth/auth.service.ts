import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { RefreshToken } from '../users/entities/refresh-token.entity';
import { AppleAuthService } from './apple-auth.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AuthResponseDto } from './dto/auth-response.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(RefreshToken)
    private refreshTokenRepository: Repository<RefreshToken>,
    private jwtService: JwtService,
    private appleAuthService: AppleAuthService,
  ) {}

  async signInWithApple(loginDto: LoginDto): Promise<AuthResponseDto> {
    // Verify Apple identity token
    const appleUser = await this.appleAuthService.verifyIdentityToken(loginDto.identityToken);
    
    // Find or create user
    let user = await this.userRepository.findOne({
      where: { apple_sub: appleUser.sub },
    });

    if (!user) {
      user = this.userRepository.create({
        apple_sub: appleUser.sub,
        display_name: loginDto.displayName || 'User',
        avatar_url: loginDto.avatarUrl,
      });
      await this.userRepository.save(user);
    }

    // Generate tokens
    const tokens = await this.generateTokens(user);
    
    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        display_name: user.display_name,
        avatar_url: user.avatar_url,
      },
    };
  }

  async refreshToken(refreshTokenDto: RefreshTokenDto): Promise<AuthResponseDto> {
    const refreshToken = await this.refreshTokenRepository.findOne({
      where: { token: refreshTokenDto.refreshToken },
      relations: ['user'],
    });

    if (!refreshToken || refreshToken.expires_at < new Date()) {
      throw new Error('Invalid or expired refresh token');
    }

    // Generate new tokens
    const tokens = await this.generateTokens(refreshToken.user);
    
    // Delete old refresh token
    await this.refreshTokenRepository.remove(refreshToken);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: refreshToken.user.id,
        display_name: refreshToken.user.display_name,
        avatar_url: refreshToken.user.avatar_url,
      },
    };
  }

  private async generateTokens(user: User) {
    const payload = { sub: user.id, apple_sub: user.apple_sub };
    
    const accessToken = this.jwtService.sign(payload, {
      expiresIn: process.env.JWT_EXPIRES_IN || '15m',
    });

    const refreshTokenValue = this.jwtService.sign(payload, {
      expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
    });

    // Save refresh token to database
    const refreshToken = this.refreshTokenRepository.create({
      user_id: user.id,
      token: refreshTokenValue,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
    });
    await this.refreshTokenRepository.save(refreshToken);

    return {
      accessToken,
      refreshToken: refreshTokenValue,
    };
  }

  async validateUser(payload: any): Promise<User> {
    return this.userRepository.findOne({
      where: { id: payload.sub },
    });
  }
}
