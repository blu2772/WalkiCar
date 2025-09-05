import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Vehicle } from './entities/vehicle.entity';
import { VehiclePosition } from './entities/vehicle-position.entity';
import { CreateVehicleDto, UpdateVehicleDto, VehiclePositionDto, NearbyVehiclesDto } from './dto/vehicle.dto';

@Injectable()
export class VehiclesService {
  constructor(
    @InjectRepository(Vehicle)
    private vehicleRepository: Repository<Vehicle>,
    @InjectRepository(VehiclePosition)
    private positionRepository: Repository<VehiclePosition>,
  ) {}

  async create(userId: number, dto: CreateVehicleDto): Promise<Vehicle> {
    const vehicle = this.vehicleRepository.create({
      user_id: userId,
      name: dto.name,
      brand: dto.brand,
      model: dto.model,
      color: dto.color,
      ble_identifier: dto.ble_identifier,
      visibility: dto.visibility || 'private',
      track_mode: dto.track_mode || 'off',
    });

    return this.vehicleRepository.save(vehicle);
  }

  async findAll(userId: number): Promise<Vehicle[]> {
    return this.vehicleRepository.find({
      where: { user_id: userId },
      relations: ['user'],
      order: { created_at: 'DESC' },
    });
  }

  async findOne(id: number, userId: number): Promise<Vehicle> {
    const vehicle = await this.vehicleRepository.findOne({
      where: { id },
      relations: ['user', 'positions'],
    });

    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    if (vehicle.user_id !== userId) {
      throw new ForbiddenException('Access denied to vehicle');
    }

    return vehicle;
  }

  async update(id: number, dto: UpdateVehicleDto, userId: number): Promise<Vehicle> {
    const vehicle = await this.findOne(id, userId);
    Object.assign(vehicle, dto);
    return this.vehicleRepository.save(vehicle);
  }

  async remove(id: number, userId: number): Promise<void> {
    const vehicle = await this.findOne(id, userId);
    await this.vehicleRepository.remove(vehicle);
  }

  async addPosition(vehicleId: number, dto: VehiclePositionDto, userId: number): Promise<VehiclePosition> {
    const vehicle = await this.findOne(vehicleId, userId);

    if (vehicle.track_mode === 'off') {
      throw new BadRequestException('Vehicle tracking is disabled');
    }

    const position = this.positionRepository.create({
      vehicle_id: vehicleId,
      lat: dto.lat,
      lon: dto.lon,
      speed: dto.speed,
      heading: dto.heading,
      moving: dto.moving || false,
    });

    return this.positionRepository.save(position);
  }

  async getNearbyVehicles(userId: number, dto: NearbyVehiclesDto): Promise<Vehicle[]> {
    const { center_lat, center_lon, radius = 5000, visibility = 'all', moving_only = false } = dto;

    let query = this.vehicleRepository
      .createQueryBuilder('vehicle')
      .leftJoinAndSelect('vehicle.user', 'user')
      .leftJoinAndSelect('vehicle.positions', 'position')
      .where('vehicle.track_mode != :trackMode', { trackMode: 'off' })
      .andWhere('position.ts >= :recentTime', { recentTime: new Date(Date.now() - 5 * 60 * 1000) }) // Last 5 minutes
      .andWhere(
        'ST_Distance_Sphere(ST_PointFromText(CONCAT("POINT(", position.lon, " ", position.lat, ")"), 4326), ST_PointFromText(CONCAT("POINT(", :lon, " ", :lat, ")"), 4326)) <= :radius',
        { lat: center_lat, lon: center_lon, radius }
      );

    // Apply visibility filter
    if (visibility === 'friends') {
      // This would need a join with friendships table in a real implementation
      query = query.andWhere('vehicle.visibility IN (:...visibilities)', { visibilities: ['friends', 'public'] });
    } else if (visibility === 'public') {
      query = query.andWhere('vehicle.visibility = :visibility', { visibility: 'public' });
    } else {
      query = query.andWhere('vehicle.visibility IN (:...visibilities)', { visibilities: ['friends', 'public'] });
    }

    // Apply moving filter
    if (moving_only) {
      query = query.andWhere('position.moving = :moving', { moving: true });
    }

    return query
      .orderBy('position.ts', 'DESC')
      .getMany();
  }

  async getLatestPosition(vehicleId: number): Promise<VehiclePosition | null> {
    return this.positionRepository.findOne({
      where: { vehicle_id: vehicleId },
      order: { ts: 'DESC' },
    });
  }

  async getVehicleHistory(vehicleId: number, userId: number, limit: number = 100): Promise<VehiclePosition[]> {
    const vehicle = await this.findOne(vehicleId, userId);
    
    return this.positionRepository.find({
      where: { vehicle_id: vehicleId },
      order: { ts: 'DESC' },
      take: limit,
    });
  }
}
