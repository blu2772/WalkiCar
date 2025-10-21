//
//  LoginView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showingEmailLogin = false
    @State private var showingEmailRegister = false
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Welcome text
                Text("Welcome!")
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                
                // Car image placeholder
                VStack {
                    Image(systemName: "car.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                    
                    Text("Sign in to connect with friends")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 60)
                
                Spacer()
                
                // Login options
                VStack(spacing: 16) {
                    // Apple Sign In Button
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    authManager.handleAppleSignIn(credential: appleIDCredential)
                                }
                            case .failure(let error):
                                authManager.errorMessage = error.localizedDescription
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(25)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                        
                        Text("oder")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    
                    // Email/Password Login Button
                    Button(action: {
                        showingEmailLogin = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                            Text("Mit E-Mail anmelden")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            
            // Loading overlay
            if authManager.isLoading {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Anmeldung läuft...")
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }
            }
        }
        .sheet(isPresented: $showingEmailLogin) {
            EmailLoginView(authManager: authManager) {
                showingEmailRegister = true
            }
        }
        .sheet(isPresented: $showingEmailRegister) {
            EmailRegisterView(authManager: authManager) {
                showingEmailLogin = true
            }
        }
        .alert("Fehler", isPresented: $showingError) {
            Button("OK") {
                authManager.errorMessage = nil
                showingError = false
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
        .onChange(of: authManager.errorMessage) { errorMessage in
            showingError = errorMessage != nil
        }
    }
}


#Preview {
    LoginView()
}
