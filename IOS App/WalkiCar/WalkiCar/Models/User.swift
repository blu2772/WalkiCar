//
//  User.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let email: String
    let emailVerified: Bool
    let profilePictureUrl: String?
    let isOnline: Bool?
    let lastSeen: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case email
        case emailVerified = "email_verified"
        case profilePictureUrl = "profile_picture_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case createdAt = "created_at"
    }
    
    // Custom initializer für flexible email_verified Typen
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decode(String.self, forKey: .email)
        
        // Flexible email_verified Dekodierung (0/1 oder true/false)
        if let boolValue = try? container.decode(Bool.self, forKey: .emailVerified) {
            emailVerified = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .emailVerified) {
            emailVerified = intValue != 0
        } else {
            emailVerified = false // Fallback
        }
        
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        
        // Flexible is_online Dekodierung
        if let boolValue = try? container.decode(Bool.self, forKey: .isOnline) {
            isOnline = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isOnline) {
            isOnline = intValue != 0
        } else {
            isOnline = nil
        }
        
        lastSeen = try container.decodeIfPresent(String.self, forKey: .lastSeen)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct AuthResponse: Codable {
    let message: String
    let token: String
    let user: User
}

struct LoginRequest: Codable {
    let appleId: String
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case appleId = "apple_id"
        case email
    }
}

struct RegisterRequest: Codable {
    let appleId: String
    let email: String
    let username: String
    let displayName: String
    
    enum CodingKeys: String, CodingKey {
        case appleId = "apple_id"
        case email
        case username
        case displayName = "display_name"
    }
}
