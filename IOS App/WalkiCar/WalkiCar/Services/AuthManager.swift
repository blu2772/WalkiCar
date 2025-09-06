//
//  AuthManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        isAuthenticated = apiClient.isAuthenticated
        if isAuthenticated {
            // TODO: Load user profile
        }
    }
    
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func logout() {
        Task {
            do {
                try await apiClient.logout()
                await MainActor.run {
                    isAuthenticated = false
                    currentUser = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            errorMessage = "Fehler beim Verarbeiten der Apple-Anmeldung"
            isLoading = false
            return
        }
        
        let email = credential.email ?? ""
        let fullName = credential.fullName
        let displayName = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        Task {
            do {
                // Versuche zuerst Login
                let response = try await apiClient.signInWithApple(
                    appleId: identityTokenString,
                    email: email
                )
                
                await MainActor.run {
                    apiClient.setAuthToken(response.token)
                    currentUser = response.user
                    isAuthenticated = true
                    isLoading = false
                }
            } catch {
                // Wenn Login fehlschlägt, versuche Registrierung
                if email.isEmpty {
                    await MainActor.run {
                        errorMessage = "E-Mail-Adresse ist für die Registrierung erforderlich"
                        isLoading = false
                    }
                    return
                }
                
                do {
                    let username = generateUsername(from: email)
                    let response = try await apiClient.registerWithApple(
                        appleId: identityTokenString,
                        email: email,
                        username: username,
                        displayName: displayName.isEmpty ? username : displayName
                    )
                    
                    await MainActor.run {
                        apiClient.setAuthToken(response.token)
                        currentUser = response.user
                        isAuthenticated = true
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isLoading = false
                    }
                }
            }
        }
    }
    
    private func generateUsername(from email: String) -> String {
        let emailPrefix = email.components(separatedBy: "@").first ?? "user"
        let cleanPrefix = emailPrefix.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(cleanPrefix)\(timestamp)"
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            handleAppleSignIn(credential: appleIDCredential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
    }
}
