import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { VoiceService } from './voice.service';
import { VoiceController } from './voice.controller';
import { GroupsModule } from '../groups/groups.module';

@Module({
  imports: [ConfigModule, GroupsModule],
  controllers: [VoiceController],
  providers: [VoiceService],
  exports: [VoiceService],
})
export class VoiceModule {}
