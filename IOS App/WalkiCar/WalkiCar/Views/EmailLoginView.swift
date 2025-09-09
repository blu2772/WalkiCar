//
//  EmailLoginView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct EmailLoginView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingForgotPassword = false
    
    // Callback für Navigation zur Registrierung
    let onShowRegister: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Anmelden")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Mit deiner E-Mail-Adresse")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("E-Mail")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            TextField("deine@email.com", text: $email)
                                .textFieldStyle(EmailTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Passwort")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            SecureField("Dein Passwort", text: $password)
                                .textFieldStyle(EmailTextFieldStyle())
                        }
                        
                        // Forgot password
                        HStack {
                            Spacer()
                            Button("Passwort vergessen?") {
                                showingForgotPassword = true
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Login button
                    Button(action: login) {
                        Text("Anmelden")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(25)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                    .padding(.horizontal, 40)
                    
                    // Register link
                    HStack {
                        Text("Noch kein Konto?")
                            .foregroundColor(.gray)
                        
                        Button("Registrieren") {
                            dismiss()
                            onShowRegister()
                        }
                        .foregroundColor(.blue)
                    }
                    .font(.system(size: 14))
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .alert("Fehler", isPresented: .constant(authManager.errorMessage != nil)) {
            Button("OK") {
                authManager.errorMessage = nil
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func login() {
        Task {
            do {
                try await authManager.loginWithEmail(email: email, password: password)
                dismiss()
            } catch {
                // Error wird bereits vom AuthManager gesetzt
            }
        }
    }
}

struct EmailTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
}

#Preview {
    EmailLoginView(authManager: AuthManager(), onShowRegister: {})
}
