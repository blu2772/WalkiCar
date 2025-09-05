import { Controller, Get, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';

import { VoiceService } from './voice.service';
import { VoiceTokenDto } from '../groups/dto/group.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@ApiTags('Voice')
@Controller('voice')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class VoiceController {
  constructor(private readonly voiceService: VoiceService) {}

  @Get('groups/:id/token')
  @ApiOperation({ summary: 'Get LiveKit join token for group voice chat' })
  @ApiResponse({ status: 200, description: 'Voice token generated successfully', type: VoiceTokenDto })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @ApiResponse({ status: 404, description: 'Group not found' })
  async getGroupVoiceToken(@Param('id') id: string, @Request() req): Promise<VoiceTokenDto> {
    return this.voiceService.generateJoinToken(req.user.id, +id);
  }
}
