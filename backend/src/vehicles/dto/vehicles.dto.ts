import { IsString, IsNumber, IsOptional, IsEnum, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { VehicleVisibility, TrackMode } from '../users/entities/vehicle.entity';

export class CreateVehicleDto {
  @ApiProperty({ description: 'Vehicle name' })
  @IsString()
  name: string;

  @ApiPropertyOptional({ description: 'Vehicle brand' })
  @IsOptional()
  @IsString()
  brand?: string;

  @ApiPropertyOptional({ description: 'Vehicle model' })
  @IsOptional()
  @IsString()
  model?: string;

  @ApiPropertyOptional({ description: 'Vehicle color' })
  @IsOptional()
  @IsString()
  color?: string;

  @ApiPropertyOptional({ description: 'BLE identifier' })
  @IsOptional()
  @IsString()
  ble_identifier?: string;

  @ApiPropertyOptional({ description: 'Visibility level', enum: VehicleVisibility })
  @IsOptional()
  @IsEnum(VehicleVisibility)
  visibility?: VehicleVisibility;

  @ApiPropertyOptional({ description: 'Tracking mode', enum: TrackMode })
  @IsOptional()
  @IsEnum(TrackMode)
  track_mode?: TrackMode;
}

export class UpdateVehicleDto {
  @ApiPropertyOptional({ description: 'Vehicle name' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ description: 'Vehicle brand' })
  @IsOptional()
  @IsString()
  brand?: string;

  @ApiPropertyOptional({ description: 'Vehicle model' })
  @IsOptional()
  @IsString()
  model?: string;

  @ApiPropertyOptional({ description: 'Vehicle color' })
  @IsOptional()
  @IsString()
  color?: string;

  @ApiPropertyOptional({ description: 'BLE identifier' })
  @IsOptional()
  @IsString()
  ble_identifier?: string;

  @ApiPropertyOptional({ description: 'Visibility level', enum: VehicleVisibility })
  @IsOptional()
  @IsEnum(VehicleVisibility)
  visibility?: VehicleVisibility;

  @ApiPropertyOptional({ description: 'Tracking mode', enum: TrackMode })
  @IsOptional()
  @IsEnum(TrackMode)
  track_mode?: TrackMode;
}

export class CreatePositionDto {
  @ApiProperty({ description: 'Latitude' })
  @IsNumber()
  lat: number;

  @ApiProperty({ description: 'Longitude' })
  @IsNumber()
  lon: number;

  @ApiPropertyOptional({ description: 'Speed in km/h' })
  @IsOptional()
  @IsNumber()
  speed?: number;

  @ApiPropertyOptional({ description: 'Heading in degrees' })
  @IsOptional()
  @IsNumber()
  heading?: number;

  @ApiPropertyOptional({ description: 'Whether vehicle is moving' })
  @IsOptional()
  @IsBoolean()
  moving?: boolean;
}

export class NearbyVehiclesDto {
  @ApiProperty({ description: 'Center latitude' })
  @IsNumber()
  centerLat: number;

  @ApiProperty({ description: 'Center longitude' })
  @IsNumber()
  centerLon: number;

  @ApiPropertyOptional({ description: 'Search radius in meters', default: 5000 })
  @IsOptional()
  @IsNumber()
  radius?: number;
}
