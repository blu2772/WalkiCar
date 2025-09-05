import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Vehicle, VehicleVisibility, TrackMode } from './entities/vehicle.entity';
import { VehiclePosition } from './entities/vehicle-position.entity';
import { User } from '../users/entities/user.entity';
import { CreateVehicleDto, UpdateVehicleDto, CreatePositionDto, NearbyVehiclesDto } from './dto/vehicles.dto';

@Injectable()
export class VehiclesService {
  constructor(
    @InjectRepository(Vehicle)
    private vehicleRepository: Repository<Vehicle>,
    @InjectRepository(VehiclePosition)
    private positionRepository: Repository<VehiclePosition>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async createVehicle(createVehicleDto: CreateVehicleDto, userId: number): Promise<Vehicle> {
    const vehicle = this.vehicleRepository.create({
      ...createVehicleDto,
      user_id: userId,
    });

    return this.vehicleRepository.save(vehicle);
  }

  async getUserVehicles(userId: number): Promise<Vehicle[]> {
    return this.vehicleRepository.find({
      where: { user_id: userId },
      order: { created_at: 'DESC' },
    });
  }

  async getVehicleById(vehicleId: number, userId: number): Promise<Vehicle> {
    const vehicle = await this.vehicleRepository.findOne({
      where: { id: vehicleId, user_id: userId },
    });

    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    return vehicle;
  }

  async updateVehicle(vehicleId: number, updateVehicleDto: UpdateVehicleDto, userId: number): Promise<Vehicle> {
    const vehicle = await this.getVehicleById(vehicleId, userId);
    
    Object.assign(vehicle, updateVehicleDto);
    return this.vehicleRepository.save(vehicle);
  }

  async deleteVehicle(vehicleId: number, userId: number): Promise<void> {
    const vehicle = await this.getVehicleById(vehicleId, userId);
    await this.vehicleRepository.remove(vehicle);
  }

  async addPosition(vehicleId: number, createPositionDto: CreatePositionDto, userId: number): Promise<VehiclePosition> {
    // Verify vehicle ownership
    await this.getVehicleById(vehicleId, userId);

    const position = this.positionRepository.create({
      ...createPositionDto,
      vehicle_id: vehicleId,
    });

    return this.positionRepository.save(position);
  }

  async getNearbyVehicles(nearbyVehiclesDto: NearbyVehiclesDto, userId: number): Promise<Vehicle[]> {
    const { centerLat, centerLon, radius = 5000 } = nearbyVehiclesDto;

    // Get user's friends for privacy filtering
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['friendships'],
    });

    const friendIds = user.friendships
      .filter(f => f.status === 'accepted')
      .map(f => f.user_id === userId ? f.friend_id : f.user_id);

    // Query vehicles within radius with privacy filtering
    const query = this.vehicleRepository
      .createQueryBuilder('vehicle')
      .leftJoin('vehicle.positions', 'position')
      .where('vehicle.track_mode != :off', { off: TrackMode.OFF })
      .andWhere('position.lat IS NOT NULL')
      .andWhere('position.lon IS NOT NULL')
      .andWhere(
        `ST_Distance_Sphere(
          ST_PointFromText(CONCAT('POINT(', position.lon, ' ', position.lat, ')'), 4326),
          ST_PointFromText(CONCAT('POINT(', :lon, ' ', :lat, ')'), 4326)
        ) <= :radius`,
        { lat: centerLat, lon: centerLon, radius }
      )
      .andWhere(
        '(vehicle.visibility = :public OR (vehicle.visibility = :friends AND vehicle.user_id IN (:...friendIds)))',
        { public: VehicleVisibility.PUBLIC, friends: VehicleVisibility.FRIENDS, friendIds }
      )
      .orderBy('position.ts', 'DESC');

    return query.getMany();
  }

  async getVehiclePositions(vehicleId: number, userId: number, limit: number = 100): Promise<VehiclePosition[]> {
    // Verify vehicle ownership or friendship
    const vehicle = await this.vehicleRepository.findOne({
      where: { id: vehicleId },
      relations: ['user', 'user.friendships'],
    });

    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    // Check access permissions
    const isOwner = vehicle.user_id === userId;
    const isFriend = vehicle.user.friendships.some(f => 
      f.status === 'accepted' && (f.user_id === userId || f.friend_id === userId)
    );
    const isPublic = vehicle.visibility === VehicleVisibility.PUBLIC;

    if (!isOwner && !isFriend && !isPublic) {
      throw new NotFoundException('Vehicle not found');
    }

    return this.positionRepository.find({
      where: { vehicle_id: vehicleId },
      order: { ts: 'DESC' },
      take: limit,
    });
  }
}
