import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule } from '@nestjs/throttler';

import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { FriendsModule } from './friends/friends.module';
import { GroupsModule } from './groups/groups.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { VoiceModule } from './voice/voice.module';

import { User } from './users/entities/user.entity';
import { Friendship } from './friends/entities/friendship.entity';
import { Group } from './groups/entities/group.entity';
import { GroupMember } from './groups/entities/group-member.entity';
import { Vehicle } from './vehicles/entities/vehicle.entity';
import { VehiclePosition } from './vehicles/entities/vehicle-position.entity';
import { RefreshToken } from './auth/entities/refresh-token.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRoot({
      type: 'mysql',
      host: process.env.MYSQL_HOST || 'localhost',
      port: parseInt(process.env.MYSQL_PORT) || 3306,
      username: process.env.MYSQL_USER || 'walkicar',
      password: process.env.MYSQL_PASSWORD || 'walkicar123',
      database: process.env.MYSQL_DB || 'walkicar',
      entities: [
        User,
        Friendship,
        Group,
        GroupMember,
        Vehicle,
        VehiclePosition,
        RefreshToken,
      ],
      synchronize: process.env.NODE_ENV === 'development',
      logging: process.env.NODE_ENV === 'development',
    }),
    ThrottlerModule.forRoot([{
      ttl: 60000, // 1 minute
      limit: 100, // 100 requests per minute
    }]),
    AuthModule,
    UsersModule,
    FriendsModule,
    GroupsModule,
    VehiclesModule,
    VoiceModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
