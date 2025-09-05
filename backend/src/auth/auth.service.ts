import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import * as crypto from 'crypto';

import { User } from '../users/entities/user.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { AppleSignInDto, RefreshTokenDto, AuthResponseDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(RefreshToken)
    private refreshTokenRepository: Repository<RefreshToken>,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async signInWithApple(dto: AppleSignInDto): Promise<AuthResponseDto> {
    try {
      // Verify Apple identity token
      const appleUser = await this.verifyAppleToken(dto.identityToken);
      
      // Find or create user
      let user = await this.userRepository.findOne({
        where: { apple_sub: appleUser.sub },
      });

      if (!user) {
        user = this.userRepository.create({
          apple_sub: appleUser.sub,
          display_name: dto.fullName || appleUser.email?.split('@')[0] || 'User',
          avatar_url: null,
        });
        user = await this.userRepository.save(user);
      }

      // Generate tokens
      const tokens = await this.generateTokens(user.id);
      
      return {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        user: {
          id: user.id,
          appleSub: user.apple_sub,
          displayName: user.display_name,
          avatarUrl: user.avatar_url,
        },
      };
    } catch (error) {
      throw new UnauthorizedException('Invalid Apple token');
    }
  }

  async refreshToken(dto: RefreshTokenDto): Promise<AuthResponseDto> {
    const refreshToken = await this.refreshTokenRepository.findOne({
      where: { token: dto.refreshToken },
      relations: ['user'],
    });

    if (!refreshToken || refreshToken.expires_at < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Generate new tokens
    const tokens = await this.generateTokens(refreshToken.user.id);
    
    // Delete old refresh token
    await this.refreshTokenRepository.delete(refreshToken.id);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: refreshToken.user.id,
        appleSub: refreshToken.user.apple_sub,
        displayName: refreshToken.user.display_name,
        avatarUrl: refreshToken.user.avatar_url,
      },
    };
  }

  private async verifyAppleToken(identityToken: string): Promise<any> {
    // In production, you should verify the token with Apple's servers
    // For now, we'll decode it (not recommended for production)
    const decoded = jwt.decode(identityToken) as any;
    
    if (!decoded || !decoded.sub) {
      throw new UnauthorizedException('Invalid Apple token');
    }

    return decoded;
  }

  private async generateTokens(userId: number): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = { sub: userId };
    const accessToken = this.jwtService.sign(payload, {
      expiresIn: this.configService.get('JWT_EXPIRES_IN', '15m'),
    });

    const refreshToken = crypto.randomBytes(64).toString('hex');
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

    await this.refreshTokenRepository.save({
      user_id: userId,
      token: refreshToken,
      expires_at: expiresAt,
    });

    return { accessToken, refreshToken };
  }

  async validateUser(payload: any): Promise<User> {
    return this.userRepository.findOne({ where: { id: payload.sub } });
  }
}
