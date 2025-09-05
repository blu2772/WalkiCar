import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn, Index } from 'typeorm';
import { Vehicle } from './vehicle.entity';

@Entity('vehicle_positions')
@Index(['vehicle_id', 'ts'], { unique: false })
export class VehiclePosition {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: number;

  @Column()
  vehicle_id: number;

  @Column({ type: 'double' })
  lat: number;

  @Column({ type: 'double' })
  lon: number;

  @Column({ type: 'double', nullable: true })
  speed: number;

  @Column({ type: 'double', nullable: true })
  heading: number;

  @Column({ default: false })
  moving: boolean;

  @CreateDateColumn({ precision: 3 })
  ts: Date;

  // Relations
  @ManyToOne(() => Vehicle, vehicle => vehicle.positions)
  @JoinColumn({ name: 'vehicle_id' })
  vehicle: Vehicle;
}
