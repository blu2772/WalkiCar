import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { VehiclePosition } from './vehicle-position.entity';

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

  @Column({ length: 100, nullable: true })
  ble_identifier: string;

  @Column({
    type: 'enum',
    enum: ['private', 'friends', 'public'],
    default: 'private',
  })
  visibility: 'private' | 'friends' | 'public';

  @Column({
    type: 'enum',
    enum: ['off', 'moving_only', 'always'],
    default: 'off',
  })
  track_mode: 'off' | 'moving_only' | 'always';

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @OneToMany(() => VehiclePosition, position => position.vehicle)
  positions: VehiclePosition[];
}
