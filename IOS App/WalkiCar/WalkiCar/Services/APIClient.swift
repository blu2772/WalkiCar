//
//  APIClient.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import AuthenticationServices

class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let baseURL = "http://localhost:3000/api"
    private var authToken: String?
    
    private init() {
        loadAuthToken()
    }
    
    // MARK: - Authentication
    
    func signInWithApple(appleId: String, email: String) async throws -> AuthResponse {
        let request = LoginRequest(appleId: appleId, email: email)
        return try await makeRequest(
            endpoint: "/auth/login",
            method: "POST",
            body: request,
            requiresAuth: false
        )
    }
    
    func registerWithApple(appleId: String, email: String, username: String, displayName: String) async throws -> AuthResponse {
        let request = RegisterRequest(
            appleId: appleId,
            email: email,
            username: username,
            displayName: displayName
        )
        return try await makeRequest(
            endpoint: "/auth/register",
            method: "POST",
            body: request,
            requiresAuth: false
        )
    }
    
    func logout() async throws {
        _ = try await makeRequest(
            endpoint: "/auth/logout",
            method: "POST",
            requiresAuth: true
        )
        clearAuthToken()
    }
    
    func refreshToken() async throws -> AuthResponse {
        return try await makeRequest(
            endpoint: "/auth/refresh",
            method: "POST",
            requiresAuth: true
        )
    }
    
    // MARK: - Friends
    
    func sendFriendRequest(username: String) async throws {
        let request = ["friend_username": username]
        _ = try await makeRequest(
            endpoint: "/friends/request",
            method: "POST",
            body: request,
            requiresAuth: true
        )
    }
    
    func getFriendRequests() async throws -> FriendRequestResponse {
        return try await makeRequest(
            endpoint: "/friends/requests",
            method: "GET",
            requiresAuth: true
        )
    }
    
    func respondToFriendRequest(friendshipId: Int, action: String) async throws {
        let request = FriendActionRequest(friendshipId: friendshipId, action: action)
        _ = try await makeRequest(
            endpoint: "/friends/action",
            method: "PUT",
            body: request,
            requiresAuth: true
        )
    }
    
    func getFriendsList() async throws -> FriendsListResponse {
        return try await makeRequest(
            endpoint: "/friends/list",
            method: "GET",
            requiresAuth: true
        )
    }
    
    func removeFriend(friendshipId: Int) async throws {
        _ = try await makeRequest(
            endpoint: "/friends/remove/\(friendshipId)",
            method: "DELETE",
            requiresAuth: true
        )
    }
    
    func searchUsers(query: String) async throws -> UserSearchResponse {
        return try await makeRequest(
            endpoint: "/friends/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            method: "GET",
            requiresAuth: true
        )
    }
    
    // MARK: - Token Management
    
    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    private func loadAuthToken() {
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
    }
    
    private func clearAuthToken() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
    
    var isAuthenticated: Bool {
        return authToken != nil
    }
    
    // MARK: - Generic Request Method
    
    private func makeRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T? = nil,
        responseType: U.Type = U.self,
        requiresAuth: Bool = true
    ) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            clearAuthToken()
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let errorMessage = try? JSONDecoder().decode(APIErrorMessage.self, from: data)
            throw APIError.serverError(errorMessage?.error ?? "Unbekannter Serverfehler")
        }
        
        do {
            return try JSONDecoder().decode(U.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError
        }
    }
    
    private func makeRequest(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            clearAuthToken()
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let errorMessage = try? JSONDecoder().decode(APIErrorMessage.self, from: data)
            throw APIError.serverError(errorMessage?.error ?? "Unbekannter Serverfehler")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError
        }
        
        return json
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige URL"
        case .invalidResponse:
            return "Ungültige Serverantwort"
        case .unauthorized:
            return "Nicht autorisiert"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Fehler beim Dekodieren der Antwort"
        }
    }
}

struct APIErrorMessage: Codable {
    let error: String
}
