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

  @Column({ unique: true })
  apple_sub: string;

  @Column({ length: 100 })
  display_name: string;

  @Column({ length: 500, nullable: true })
  avatar_url: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

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
