import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return '🚗 WalkiCar Backend API is running!';
  }

  getHealth() {
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'walkicar-backend',
      version: '1.0.0',
    };
  }
}
