import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';

import { VehiclesService } from './vehicles.service';
import { CreateVehicleDto, UpdateVehicleDto, VehiclePositionDto, NearbyVehiclesDto, VehicleDto } from './dto/vehicle.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Vehicles')
@Controller('vehicles')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new vehicle' })
  @ApiResponse({ status: 201, description: 'Vehicle created successfully', type: VehicleDto })
  async create(@Body() dto: CreateVehicleDto, @Request() req) {
    return this.vehiclesService.create(req.user.id, dto);
  }

  @Get('mine')
  @ApiOperation({ summary: 'Get user vehicles' })
  @ApiResponse({ status: 200, description: 'List of user vehicles', type: [VehicleDto] })
  async findAll(@Request() req) {
    return this.vehiclesService.findAll(req.user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get vehicle by ID' })
  @ApiResponse({ status: 200, description: 'Vehicle information', type: VehicleDto })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async findOne(@Param('id') id: string, @Request() req) {
    return this.vehiclesService.findOne(+id, req.user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update vehicle' })
  @ApiResponse({ status: 200, description: 'Vehicle updated successfully', type: VehicleDto })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async update(@Param('id') id: string, @Body() dto: UpdateVehicleDto, @Request() req) {
    return this.vehiclesService.update(+id, dto, req.user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete vehicle' })
  @ApiResponse({ status: 200, description: 'Vehicle deleted successfully' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async remove(@Param('id') id: string, @Request() req) {
    await this.vehiclesService.remove(+id, req.user.id);
    return { message: 'Vehicle deleted successfully' };
  }

  @Post(':id/positions')
  @UseGuards(ThrottlerGuard)
  @ApiOperation({ summary: 'Add vehicle position' })
  @ApiResponse({ status: 201, description: 'Position added successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async addPosition(@Param('id') id: string, @Body() dto: VehiclePositionDto, @Request() req) {
    return this.vehiclesService.addPosition(+id, dto, req.user.id);
  }

  @Get(':id/positions')
  @ApiOperation({ summary: 'Get vehicle position history' })
  @ApiResponse({ status: 200, description: 'Vehicle position history' })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async getHistory(@Param('id') id: string, @Query('limit') limit: string, @Request() req) {
    return this.vehiclesService.getVehicleHistory(+id, req.user.id, limit ? +limit : 100);
  }

  @Get('map/nearby')
  @ApiOperation({ summary: 'Get nearby vehicles' })
  @ApiResponse({ status: 200, description: 'List of nearby vehicles', type: [VehicleDto] })
  async getNearbyVehicles(@Query() dto: NearbyVehiclesDto, @Request() req) {
    return this.vehiclesService.getNearbyVehicles(req.user.id, dto);
  }
}
