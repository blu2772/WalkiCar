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
    
    private let baseURL = "https://timrmp.de/api"
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
            body: Optional<[String: String]>.none,
            responseType: [String: String].self,
            requiresAuth: true
        )
        clearAuthToken()
    }
    
    func refreshToken() async throws -> AuthResponse {
        return try await makeRequest(
            endpoint: "/auth/refresh",
            method: "POST",
            body: Optional<[String: String]>.none,
            responseType: AuthResponse.self,
            requiresAuth: true
        )
    }
    
    // MARK: - Email/Password Authentication
    
    func registerWithEmail(email: String, username: String, displayName: String, password: String) async throws -> AuthResponse {
        print("📧 APIClient: E-Mail-Registrierung gestartet")
        print("📧 E-Mail: \(email)")
        print("📧 Username: \(username)")
        print("📧 Display Name: \(displayName)")
        
        let request = EmailRegisterRequest(
            email: email,
            username: username,
            displayName: displayName,
            password: password
        )
        
        print("📧 Request erstellt, API-Aufruf gestartet...")
        let response = try await makeRequest(
            endpoint: "/auth/register-email",
            method: "POST",
            body: request,
            responseType: AuthResponse.self,
            requiresAuth: false
        )
        print("📧 API-Antwort erhalten: \(response)")
        
        return response
    }
    
    func loginWithEmail(email: String, password: String) async throws -> AuthResponse {
        let request = EmailLoginRequest(email: email, password: password)
        return try await makeRequest(
            endpoint: "/auth/login-email",
            method: "POST",
            body: request,
            requiresAuth: false
        )
    }
    
    func forgotPassword(email: String) async throws {
        let request = PasswordResetRequest(email: email)
        _ = try await makeRequest(
            endpoint: "/auth/forgot-password",
            method: "POST",
            body: request,
            responseType: [String: String].self,
            requiresAuth: false
        )
    }
    
    func resetPassword(token: String, password: String) async throws {
        let request = PasswordResetConfirmRequest(token: token, password: password)
        _ = try await makeRequest(
            endpoint: "/auth/reset-password",
            method: "POST",
            body: request,
            responseType: [String: String].self,
            requiresAuth: false
        )
    }
    
    func verifyEmail(token: String) async throws {
        let request = ["token": token]
        _ = try await makeRequestDict(
            endpoint: "/auth/verify-email",
            method: "POST",
            body: request,
            requiresAuth: false
        )
    }
    
    // MARK: - Friends
    
    func sendFriendRequest(username: String) async throws {
        let request = ["friend_username": username]
        _ = try await makeRequestDict(
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
            body: Optional<[String: String]>.none,
            responseType: FriendRequestResponse.self,
            requiresAuth: true
        )
    }
    
    func respondToFriendRequest(friendshipId: Int, action: String) async throws {
        let request = FriendActionRequest(friendshipId: friendshipId, action: action)
        _ = try await makeRequest(
            endpoint: "/friends/action",
            method: "PUT",
            body: request,
            responseType: [String: String].self,
            requiresAuth: true
        )
    }
    
    func getFriendsList() async throws -> FriendsListResponse {
        return try await makeRequest(
            endpoint: "/friends/list",
            method: "GET",
            body: Optional<[String: String]>.none,
            responseType: FriendsListResponse.self,
            requiresAuth: true
        )
    }
    
    func removeFriend(friendshipId: Int) async throws {
        _ = try await makeRequestDict(
            endpoint: "/friends/remove/\(friendshipId)",
            method: "DELETE",
            requiresAuth: true
        )
    }
    
    func searchUsers(query: String) async throws -> UserSearchResponse {
        return try await makeRequest(
            endpoint: "/friends/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            method: "GET",
            body: Optional<[String: String]>.none,
            responseType: UserSearchResponse.self,
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
        print("🌐 API-Aufruf: \(method) \(baseURL + endpoint)")
        
        guard let url = URL(string: baseURL + endpoint) else {
            print("❌ Ungültige URL: \(baseURL + endpoint)")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 Auth-Token gesetzt")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
            print("📦 Request Body gesetzt")
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("📦 Request Body Inhalt: \(bodyString)")
            }
        }
        
        print("📡 HTTP-Request wird gesendet...")
        
        // Benutzerdefinierte URLSession für HTTP-Verbindungen
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Ungültige HTTP-Response")
            throw APIError.invalidResponse
        }
        
        print("📊 HTTP-Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            print("🔒 Unauthorized - Token wird gelöscht")
            clearAuthToken()
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            print("❌ Server-Fehler: \(httpResponse.statusCode)")
            let errorMessage = try? JSONDecoder().decode(APIErrorMessage.self, from: data)
            print("❌ Fehler-Message: \(errorMessage?.error ?? "Unbekannter Serverfehler")")
            throw APIError.serverError(errorMessage?.error ?? "Unbekannter Serverfehler")
        }
        
        do {
            let result = try JSONDecoder().decode(U.self, from: data)
            print("✅ Response erfolgreich dekodiert")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response Data: \(responseString)")
            }
            return result
        } catch {
            print("❌ Decoding-Fehler: \(error)")
            print("📄 Response Data: \(String(data: data, encoding: .utf8) ?? "Keine Daten")")
            throw APIError.decodingError
        }
    }
    
    private func makeRequestDict(
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

// MARK: - Request Models

struct EmailRegisterRequest: Codable {
    let email: String
    let username: String
    let displayName: String
    let password: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case username
        case displayName = "display_name"
        case password
    }
}

struct EmailLoginRequest: Codable {
    let email: String
    let password: String
}

struct PasswordResetRequest: Codable {
    let email: String
}

struct PasswordResetConfirmRequest: Codable {
    let token: String
    let password: String
}
