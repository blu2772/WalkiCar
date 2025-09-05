import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersService } from './users.service';
import { User } from './entities/user.entity';
import { Friendship } from './entities/friendship.entity';
import { Group } from './entities/group.entity';
import { GroupMember } from './entities/group-member.entity';
import { Vehicle } from './entities/vehicle.entity';
import { VehiclePosition } from './entities/vehicle-position.entity';
import { RefreshToken } from './entities/refresh-token.entity';

@Module({
  imports: [TypeOrmModule.forFeature([
    User,
    Friendship,
    Group,
    GroupMember,
    Vehicle,
    VehiclePosition,
    RefreshToken,
  ])],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
