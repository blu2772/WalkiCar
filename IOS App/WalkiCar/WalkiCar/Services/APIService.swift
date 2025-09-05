//
//  APIService.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import Combine

class APIService: ObservableObject {
  private let baseURL = "http://localhost:3000/api/v1"
  private var cancellables = Set<AnyCancellable>()
  
  private var accessToken: String? {
    UserDefaults.standard.string(forKey: "accessToken")
  }
  
  private var refreshToken: String? {
    UserDefaults.standard.string(forKey: "refreshToken")
  }
  
  // MARK: - Auth
  
  func signInWithApple(request: AppleSignInRequest) -> AnyPublisher<AuthResponse, Error> {
    return request(endpoint: "/auth/apple", method: "POST", body: request)
  }
  
  func getCurrentUser() -> AnyPublisher<User, Error> {
    return request(endpoint: "/auth/me", method: "GET")
  }
  
  // MARK: - Friends
  
  func getFriends() -> AnyPublisher<[Friendship], Error> {
    return request(endpoint: "/friends", method: "GET")
  }
  
  func searchUsers(query: String) -> AnyPublisher<[User], Error> {
    return request(endpoint: "/users/search?query=\(query)", method: "GET")
  }
  
  func sendFriendRequest(userId: Int) -> AnyPublisher<Friendship, Error> {
    let request = SendFriendRequestRequest(userId: userId)
    return request(endpoint: "/friends/requests", method: "POST", body: request)
  }
  
  // MARK: - Groups
  
  func getGroups() -> AnyPublisher<[Group], Error> {
    return request(endpoint: "/groups", method: "GET")
  }
  
  func createGroup(name: String, description: String?, isPublic: Bool) -> AnyPublisher<Group, Error> {
    let request = CreateGroupRequest(name: name, description: description, isPublic: isPublic)
    return request(endpoint: "/groups", method: "POST", body: request)
  }
  
  func joinGroup(groupId: Int) -> AnyPublisher<GroupMember, Error> {
    return request(endpoint: "/groups/\(groupId)/join", method: "POST")
  }
  
  func getVoiceToken(groupId: Int) -> AnyPublisher<VoiceToken, Error> {
    return request(endpoint: "/voice/groups/\(groupId)/token", method: "GET")
  }
  
  // MARK: - Vehicles
  
  func getVehicles() -> AnyPublisher<[Vehicle], Error> {
    return request(endpoint: "/vehicles/mine", method: "GET")
  }
  
  func createVehicle(name: String, brand: String?, model: String?, color: String?, visibility: String, trackMode: String) -> AnyPublisher<Vehicle, Error> {
    let request = CreateVehicleRequest(
      name: name,
      brand: brand,
      model: model,
      color: color,
      visibility: visibility,
      trackMode: trackMode
    )
    return request(endpoint: "/vehicles", method: "POST", body: request)
  }
  
  func getNearbyVehicles(centerLat: Double, centerLon: Double, radius: Int) -> AnyPublisher<[Vehicle], Error> {
    return request(endpoint: "/vehicles/map/nearby?center_lat=\(centerLat)&center_lon=\(centerLon)&radius=\(radius)", method: "GET")
  }
  
  func addVehiclePosition(vehicleId: Int, lat: Double, lon: Double, speed: Double?, heading: Double?, moving: Bool) -> AnyPublisher<VehiclePosition, Error> {
    let request = VehiclePositionRequest(lat: lat, lon: lon, speed: speed, heading: heading, moving: moving)
    return request(endpoint: "/vehicles/\(vehicleId)/positions", method: "POST", body: request)
  }
  
  // MARK: - Generic Request Method
  
  private func request<T: Codable, R: Codable>(
    endpoint: String,
    method: String,
    body: T? = nil
  ) -> AnyPublisher<R, Error> {
    guard let url = URL(string: baseURL + endpoint) else {
      return Fail(error: APIError.invalidURL)
        .eraseToAnyPublisher()
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    if let token = accessToken {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    if let body = body {
      do {
        request.httpBody = try JSONEncoder().encode(body)
      } catch {
        return Fail(error: error)
          .eraseToAnyPublisher()
      }
    }
    
    return URLSession.shared.dataTaskPublisher(for: request)
      .map(\.data)
      .decode(type: R.self, decoder: JSONDecoder())
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
}

enum APIError: Error {
  case invalidURL
  case noData
  case decodingError
}

// MARK: - Data Models

struct Friendship: Codable, Identifiable {
  let id: Int
  let userId: Int
  let friendId: Int
  let status: String
  let friend: User
  let createdAt: Date
}

struct Group: Codable, Identifiable {
  let id: Int
  let name: String
  let description: String?
  let isPublic: Bool
  let owner: User
  let memberCount: Int
  let createdAt: Date
}

struct GroupMember: Codable, Identifiable {
  let id: Int
  let groupId: Int
  let userId: Int
  let role: String
  let joinedAt: Date
}

struct Vehicle: Codable, Identifiable {
  let id: Int
  let name: String
  let brand: String?
  let model: String?
  let color: String?
  let visibility: String
  let trackMode: String
  let user: User
  let latestPosition: VehiclePosition?
  let createdAt: Date
}

struct VehiclePosition: Codable, Identifiable {
  let id: Int
  let vehicleId: Int
  let lat: Double
  let lon: Double
  let speed: Double?
  let heading: Double?
  let moving: Bool
  let ts: Date
}

struct VoiceToken: Codable {
  let token: String
  let url: String
  let room: String
}

// MARK: - Request Models

struct SendFriendRequestRequest: Codable {
  let userId: Int
}

struct CreateGroupRequest: Codable {
  let name: String
  let description: String?
  let isPublic: Bool
}

struct CreateVehicleRequest: Codable {
  let name: String
  let brand: String?
  let model: String?
  let color: String?
  let visibility: String
  let trackMode: String
}

struct VehiclePositionRequest: Codable {
  let lat: Double
  let lon: Double
  let speed: Double?
  let heading: Double?
  let moving: Bool
}
