import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { Friendship } from './friendship.entity';
import { Group } from './group.entity';
import { GroupMember } from './group-member.entity';
import { Vehicle } from './vehicle.entity';
import { RefreshToken } from './refresh-token.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'apple_sub', unique: true, nullable: true })
  appleSub?: string;

  @Column({ unique: true, nullable: true })
  email?: string;

  @Column({ name: 'password_hash', nullable: true })
  passwordHash?: string;

  @Column({ name: 'display_name', length: 100 })
  displayName: string;

  @Column({ name: 'avatar_url', length: 500, nullable: true })
  avatarUrl?: string;

  @Column({ name: 'email_verified', default: false })
  emailVerified: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @OneToMany(() => Friendship, friendship => friendship.user)
  friendships: Friendship[];

  @OneToMany(() => Friendship, friendship => friendship.friend)
  friendOf: Friendship[];

  @OneToMany(() => Group, group => group.owner)
  ownedGroups: Group[];

  @OneToMany(() => GroupMember, member => member.user)
  groupMemberships: GroupMember[];

  @OneToMany(() => Vehicle, vehicle => vehicle.user)
  vehicles: Vehicle[];

  @OneToMany(() => RefreshToken, token => token.user)
  refreshTokens: RefreshToken[];
}
