//
//  Friend.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation

struct Friend: Codable, Identifiable {
    let friendshipId: Int
    let id: Int
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    let isOnline: Bool
    let lastSeen: String?
    let activeCar: ActiveCar?
    
    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case id
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case activeCar = "active_car"
    }
}

struct ActiveCar: Codable {
    let id: Int
    let name: String
    let brand: String?
    let model: String?
    let color: String?
}

struct FriendRequest: Codable, Identifiable {
    let id: Int
    let createdAt: String
    let userId: Int
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
    }
}

struct FriendRequestResponse: Codable {
    let requests: [FriendRequest]
}

struct FriendsListResponse: Codable {
    let friends: [Friend]
}

struct FriendActionRequest: Codable {
    let friendshipId: Int
    let action: String
    
    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case action
    }
}

struct UserSearchResult: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    let isOnline: Bool
    let relationshipStatus: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
        case isOnline = "is_online"
        case relationshipStatus = "relationship_status"
    }
}

struct UserSearchResponse: Codable {
    let users: [UserSearchResult]
}
