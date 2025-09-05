import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleDto, UpdateVehicleDto, CreatePositionDto, NearbyVehiclesDto } from './dto/vehicles.dto';

@ApiTags('Vehicles')
@Controller('vehicles')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new vehicle' })
  @ApiResponse({ status: 201, description: 'Vehicle created successfully' })
  async createVehicle(@Body() createVehicleDto: CreateVehicleDto, @Request() req) {
    return this.vehiclesService.createVehicle(createVehicleDto, req.user.id);
  }

  @Get('mine')
  @ApiOperation({ summary: 'Get user vehicles' })
  @ApiResponse({ status: 200, description: 'List of user vehicles' })
  async getUserVehicles(@Request() req) {
    return this.vehiclesService.getUserVehicles(req.user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get vehicle by ID' })
  @ApiResponse({ status: 200, description: 'Vehicle details' })
  async getVehicleById(@Param('id') id: string, @Request() req) {
    return this.vehiclesService.getVehicleById(parseInt(id), req.user.id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update vehicle' })
  @ApiResponse({ status: 200, description: 'Vehicle updated successfully' })
  async updateVehicle(@Param('id') id: string, @Body() updateVehicleDto: UpdateVehicleDto, @Request() req) {
    return this.vehiclesService.updateVehicle(parseInt(id), updateVehicleDto, req.user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete vehicle' })
  @ApiResponse({ status: 200, description: 'Vehicle deleted successfully' })
  async deleteVehicle(@Param('id') id: string, @Request() req) {
    return this.vehiclesService.deleteVehicle(parseInt(id), req.user.id);
  }

  @Post(':id/positions')
  @ApiOperation({ summary: 'Add vehicle position' })
  @ApiResponse({ status: 201, description: 'Position added successfully' })
  async addPosition(@Param('id') id: string, @Body() createPositionDto: CreatePositionDto, @Request() req) {
    return this.vehiclesService.addPosition(parseInt(id), createPositionDto, req.user.id);
  }

  @Get(':id/positions')
  @ApiOperation({ summary: 'Get vehicle positions' })
  @ApiResponse({ status: 200, description: 'List of vehicle positions' })
  async getVehiclePositions(@Param('id') id: string, @Query('limit') limit: string, @Request() req) {
    return this.vehiclesService.getVehiclePositions(parseInt(id), req.user.id, parseInt(limit) || 100);
  }
}

@ApiTags('Map')
@Controller('map')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class MapController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Get('nearby')
  @ApiOperation({ summary: 'Get nearby vehicles' })
  @ApiResponse({ status: 200, description: 'List of nearby vehicles' })
  async getNearbyVehicles(@Query() nearbyVehiclesDto: NearbyVehiclesDto, @Request() req) {
    return this.vehiclesService.getNearbyVehicles(nearbyVehiclesDto, req.user.id);
  }
}
