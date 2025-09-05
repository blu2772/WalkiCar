import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn } from 'typeorm';
import { Vehicle } from './vehicle.entity';

@Entity('vehicle_positions')
export class VehiclePosition {
  @PrimaryGeneratedColumn()
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

  @Column({ type: 'timestamp', precision: 3, default: () => 'CURRENT_TIMESTAMP(3)' })
  ts: Date;

  @Column({ default: false })
  moving: boolean;

  @Column({
    type: 'point',
    spatialFeatureType: 'Point',
    srid: 4326,
    generatedType: 'STORED',
    asExpression: `ST_PointFromText(CONCAT('POINT(', lon, ' ', lat, ')'), 4326)`,
  })
  location: any;

  @ManyToOne(() => Vehicle, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'vehicle_id' })
  vehicle: Vehicle;
}
