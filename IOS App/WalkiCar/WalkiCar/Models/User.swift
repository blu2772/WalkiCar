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
    let profilePictureUrl: String?
    let isOnline: Bool
    let lastSeen: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case email
        case profilePictureUrl = "profile_picture_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case createdAt = "created_at"
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
