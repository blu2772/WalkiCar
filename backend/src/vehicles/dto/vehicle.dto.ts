import { IsString, IsNotEmpty, IsOptional, IsEnum, IsNumber, IsBoolean, Length, Min, Max } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateVehicleDto {
  @ApiProperty({ description: 'Vehicle name', minLength: 1, maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @Length(1, 100)
  name: string;

  @ApiProperty({ description: 'Vehicle brand', required: false })
  @IsString()
  @IsOptional()
  brand?: string;

  @ApiProperty({ description: 'Vehicle model', required: false })
  @IsString()
  @IsOptional()
  model?: string;

  @ApiProperty({ description: 'Vehicle color', required: false })
  @IsString()
  @IsOptional()
  color?: string;

  @ApiProperty({ description: 'BLE identifier', required: false })
  @IsString()
  @IsOptional()
  ble_identifier?: string;

  @ApiProperty({ description: 'Visibility setting', enum: ['private', 'friends', 'public'], default: 'private' })
  @IsEnum(['private', 'friends', 'public'])
  @IsOptional()
  visibility?: 'private' | 'friends' | 'public';

  @ApiProperty({ description: 'Tracking mode', enum: ['off', 'moving_only', 'always'], default: 'off' })
  @IsEnum(['off', 'moving_only', 'always'])
  @IsOptional()
  track_mode?: 'off' | 'moving_only' | 'always';
}

export class UpdateVehicleDto {
  @ApiProperty({ description: 'Vehicle name', minLength: 1, maxLength: 100, required: false })
  @IsString()
  @IsOptional()
  @Length(1, 100)
  name?: string;

  @ApiProperty({ description: 'Vehicle brand', required: false })
  @IsString()
  @IsOptional()
  brand?: string;

  @ApiProperty({ description: 'Vehicle model', required: false })
  @IsString()
  @IsOptional()
  model?: string;

  @ApiProperty({ description: 'Vehicle color', required: false })
  @IsString()
  @IsOptional()
  color?: string;

  @ApiProperty({ description: 'BLE identifier', required: false })
  @IsString()
  @IsOptional()
  ble_identifier?: string;

  @ApiProperty({ description: 'Visibility setting', enum: ['private', 'friends', 'public'], required: false })
  @IsEnum(['private', 'friends', 'public'])
  @IsOptional()
  visibility?: 'private' | 'friends' | 'public';

  @ApiProperty({ description: 'Tracking mode', enum: ['off', 'moving_only', 'always'], required: false })
  @IsEnum(['off', 'moving_only', 'always'])
  @IsOptional()
  track_mode?: 'off' | 'moving_only' | 'always';
}

export class VehiclePositionDto {
  @ApiProperty({ description: 'Latitude', minimum: -90, maximum: 90 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat: number;

  @ApiProperty({ description: 'Longitude', minimum: -180, maximum: 180 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  lon: number;

  @ApiProperty({ description: 'Speed in km/h', required: false })
  @IsNumber()
  @IsOptional()
  speed?: number;

  @ApiProperty({ description: 'Heading in degrees', minimum: 0, maximum: 360, required: false })
  @IsNumber()
  @IsOptional()
  @Min(0)
  @Max(360)
  heading?: number;

  @ApiProperty({ description: 'Is vehicle moving', required: false })
  @IsBoolean()
  @IsOptional()
  moving?: boolean;
}

export class VehicleDto {
  @ApiProperty({ description: 'Vehicle ID' })
  id: number;

  @ApiProperty({ description: 'Vehicle name' })
  name: string;

  @ApiProperty({ description: 'Vehicle brand' })
  brand: string;

  @ApiProperty({ description: 'Vehicle model' })
  model: string;

  @ApiProperty({ description: 'Vehicle color' })
  color: string;

  @ApiProperty({ description: 'BLE identifier' })
  ble_identifier: string;

  @ApiProperty({ description: 'Visibility setting' })
  visibility: 'private' | 'friends' | 'public';

  @ApiProperty({ description: 'Tracking mode' })
  track_mode: 'off' | 'moving_only' | 'always';

  @ApiProperty({ description: 'Owner information' })
  user: {
    id: number;
    display_name: string;
    avatar_url?: string;
  };

  @ApiProperty({ description: 'Latest position', required: false })
  latestPosition?: {
    lat: number;
    lon: number;
    speed?: number;
    heading?: number;
    moving: boolean;
    ts: Date;
  };

  @ApiProperty({ description: 'Created at timestamp' })
  created_at: Date;
}

export class NearbyVehiclesDto {
  @ApiProperty({ description: 'Center latitude', minimum: -90, maximum: 90 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  center_lat: number;

  @ApiProperty({ description: 'Center longitude', minimum: -180, maximum: 180 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  center_lon: number;

  @ApiProperty({ description: 'Search radius in meters', minimum: 100, maximum: 50000, default: 5000 })
  @IsNumber()
  @IsOptional()
  @Min(100)
  @Max(50000)
  radius?: number;

  @ApiProperty({ description: 'Filter by visibility', enum: ['friends', 'public', 'all'], default: 'all' })
  @IsEnum(['friends', 'public', 'all'])
  @IsOptional()
  visibility?: 'friends' | 'public' | 'all';

  @ApiProperty({ description: 'Only show moving vehicles', default: false })
  @IsBoolean()
  @IsOptional()
  moving_only?: boolean;
}
