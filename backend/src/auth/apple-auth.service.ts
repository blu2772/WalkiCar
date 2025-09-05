import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import * as jwksClient from 'jwks-rsa';

interface AppleUser {
  sub: string;
  email?: string;
  email_verified?: boolean;
}

@Injectable()
export class AppleAuthService {
  private readonly client: jwksClient.JwksClient;

  constructor(private configService: ConfigService) {
    this.client = jwksClient({
      jwksUri: 'https://appleid.apple.com/auth/keys',
      cache: true,
      cacheMaxAge: 600000, // 10 minutes
    });
  }

  async verifyIdentityToken(identityToken: string): Promise<AppleUser> {
    try {
      // Decode token header to get key ID
      const decoded = jwt.decode(identityToken, { complete: true });
      if (!decoded || typeof decoded === 'string') {
        throw new Error('Invalid token format');
      }

      const { kid } = decoded.header;
      if (!kid) {
        throw new Error('Token missing key ID');
      }

      // Get Apple's public key
      const key = await this.getApplePublicKey(kid);
      
      // Verify token
      const payload = jwt.verify(identityToken, key, {
        algorithms: ['RS256'],
        issuer: 'https://appleid.apple.com',
        audience: this.configService.get('APPLE_CLIENT_ID'),
      }) as AppleUser;

      return payload;
    } catch (error) {
      throw new Error(`Apple token verification failed: ${error.message}`);
    }
  }

  private async getApplePublicKey(kid: string): Promise<string> {
    return new Promise((resolve, reject) => {
      this.client.getSigningKey(kid, (err, key) => {
        if (err) {
          reject(err);
        } else {
          resolve(key.getPublicKey());
        }
      });
    });
  }
}
