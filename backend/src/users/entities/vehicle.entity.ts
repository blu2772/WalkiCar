import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { User } from './user.entity';
import { VehiclePosition } from './vehicle-position.entity';

export enum VehicleVisibility {
  PRIVATE = 'private',
  FRIENDS = 'friends',
  PUBLIC = 'public',
}

export enum TrackMode {
  OFF = 'off',
  MOVING_ONLY = 'moving_only',
  ALWAYS = 'always',
}

@Entity('vehicles')
export class Vehicle {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  user_id: number;

  @Column({ length: 100 })
  name: string;

  @Column({ length: 50, nullable: true })
  brand: string;

  @Column({ length: 50, nullable: true })
  model: string;

  @Column({ length: 30, nullable: true })
  color: string;

  @Column({ length: 255, nullable: true })
  ble_identifier: string;

  @Column({
    type: 'enum',
    enum: VehicleVisibility,
    default: VehicleVisibility.PRIVATE,
  })
  visibility: VehicleVisibility;

  @Column({
    type: 'enum',
    enum: TrackMode,
    default: TrackMode.OFF,
  })
  track_mode: TrackMode;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  // Relations
  @ManyToOne(() => User, user => user.vehicles)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @OneToMany(() => VehiclePosition, position => position.vehicle)
  positions: VehiclePosition[];
}
