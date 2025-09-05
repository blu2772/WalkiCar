//
//  AuthManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import AuthenticationServices
import Combine

class AuthManager: ObservableObject {
  @Published var isAuthenticated = false
  @Published var currentUser: User?
  @Published var isLoading = false
  
  private let apiService = APIService()
  private var cancellables = Set<AnyCancellable>()
  
  init() {
    checkAuthenticationStatus()
  }
  
  func signInWithApple(credential: ASAuthorizationAppleIDCredential) {
    isLoading = true
    
    guard let identityToken = credential.identityToken,
          let identityTokenString = String(data: identityToken, encoding: .utf8) else {
      isLoading = false
      return
    }
    
    let authCode = credential.authorizationCode.map { String(data: $0, encoding: .utf8) } ?? nil
    let email = credential.email
    let fullName = credential.fullName?.formatted() ?? ""
    
    let request = AppleSignInRequest(
      identityToken: identityTokenString,
      authorizationCode: authCode ?? "",
      email: email,
      fullName: fullName
    )
    
    apiService.signInWithApple(request: request)
      .sink(
        receiveCompletion: { [weak self] completion in
          self?.isLoading = false
          if case .failure(let error) = completion {
            print("Sign in failed: \(error)")
          }
        },
        receiveValue: { [weak self] response in
          self?.handleSignInSuccess(response)
        }
      )
      .store(in: &cancellables)
  }
  
  func signOut() {
    // Clear stored tokens
    UserDefaults.standard.removeObject(forKey: "accessToken")
    UserDefaults.standard.removeObject(forKey: "refreshToken")
    
    isAuthenticated = false
    currentUser = nil
  }
  
  private func handleSignInSuccess(_ response: AuthResponse) {
    // Store tokens
    UserDefaults.standard.set(response.accessToken, forKey: "accessToken")
    UserDefaults.standard.set(response.refreshToken, forKey: "refreshToken")
    
    currentUser = response.user
    isAuthenticated = true
  }
  
  private func checkAuthenticationStatus() {
    if let accessToken = UserDefaults.standard.string(forKey: "accessToken") {
      // Verify token is still valid
      apiService.getCurrentUser()
        .sink(
          receiveCompletion: { [weak self] completion in
            if case .failure = completion {
              self?.signOut()
            }
          },
          receiveValue: { [weak self] user in
            self?.currentUser = user
            self?.isAuthenticated = true
          }
        )
        .store(in: &cancellables)
    }
  }
}

struct User: Codable, Identifiable {
  let id: Int
  let appleSub: String
  let displayName: String
  let avatarUrl: String?
}

struct AuthResponse: Codable {
  let accessToken: String
  let refreshToken: String
  let user: User
}

struct AppleSignInRequest: Codable {
  let identityToken: String
  let authorizationCode: String
  let email: String?
  let fullName: String?
}
