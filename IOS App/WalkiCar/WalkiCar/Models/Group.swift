//
//  Group.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation

struct Group: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let creatorId: Int
    let isPublic: Bool
    let maxMembers: Int
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
    let memberCount: Int
    let voiceChatActive: Bool?
    let voiceChatStartedAt: String?
    let members: [GroupMember]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case creatorId = "creator_id"
        case isPublic = "is_public"
        case maxMembers = "max_members"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
        case voiceChatActive = "voice_chat_active"
        case voiceChatStartedAt = "voice_chat_started_at"
        case members
    }
    
    // Custom initializer für flexible voice_chat_active Dekodierung
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        creatorId = try container.decode(Int.self, forKey: .creatorId)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        maxMembers = try container.decode(Int.self, forKey: .maxMembers)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        voiceChatStartedAt = try container.decodeIfPresent(String.self, forKey: .voiceChatStartedAt)
        members = try container.decode([GroupMember].self, forKey: .members)
        
        // Flexible voice_chat_active Dekodierung (0/1 oder true/false oder null)
        if let boolValue = try? container.decode(Bool.self, forKey: .voiceChatActive) {
            voiceChatActive = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .voiceChatActive) {
            voiceChatActive = intValue != 0
        } else {
            voiceChatActive = nil
        }
    }
}

struct GroupMember: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    let isOnline: Bool
    let role: String
    let joinedAt: String
    let inVoiceChat: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
        case isOnline = "is_online"
        case role
        case joinedAt = "joined_at"
        case inVoiceChat = "in_voice_chat"
    }
    
    // Custom initializer für flexible is_online und in_voice_chat Dekodierung
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        role = try container.decode(String.self, forKey: .role)
        joinedAt = try container.decode(String.self, forKey: .joinedAt)
        
        // Flexible is_online Dekodierung (0/1 oder true/false)
        if let boolValue = try? container.decode(Bool.self, forKey: .isOnline) {
            isOnline = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isOnline) {
            isOnline = intValue != 0
        } else {
            isOnline = false // Fallback
        }
        
        // Flexible in_voice_chat Dekodierung (0/1 oder true/false oder null)
        if let boolValue = try? container.decode(Bool.self, forKey: .inVoiceChat) {
            inVoiceChat = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .inVoiceChat) {
            inVoiceChat = intValue != 0
        } else {
            inVoiceChat = nil
        }
    }
}

struct VoiceChatParticipant: Codable, Identifiable {
    let userId: Int
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    let startedAt: String
    let isActive: Bool
    
    var id: Int { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
        case startedAt = "started_at"
        case isActive = "is_active"
    }
}

struct VoiceChatStatus: Codable {
    let participants: [VoiceChatParticipant]
    let isActive: Bool
    let participantCount: Int
}

struct CreateGroupRequest: Codable {
    let name: String
    let description: String?
    let friendIds: [Int]
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case friendIds = "friendIds"
    }
}

struct GroupsListResponse: Codable {
    let groups: [Group]
}

struct GroupActionResponse: Codable {
    let success: Bool
    let message: String
    let groupId: Int?
}
