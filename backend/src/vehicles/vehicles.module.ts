import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VehiclesController, MapController } from './vehicles.controller';
import { VehiclesService } from './vehicles.service';
import { Vehicle } from '../users/entities/vehicle.entity';
import { VehiclePosition } from '../users/entities/vehicle-position.entity';
import { User } from '../users/entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Vehicle, VehiclePosition, User])],
  controllers: [VehiclesController, MapController],
  providers: [VehiclesService],
  exports: [VehiclesService],
})
export class VehiclesModule {}
