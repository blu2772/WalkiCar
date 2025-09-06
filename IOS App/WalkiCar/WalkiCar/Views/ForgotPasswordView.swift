//
//  ForgotPasswordView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Passwort vergessen")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Gib deine E-Mail-Adresse ein und wir senden dir einen Link zum Zurücksetzen")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 40)
                    
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
                    .padding(.horizontal, 40)
                    
                    // Send button
                    Button(action: sendResetEmail) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Wird gesendet..." : "Reset-Link senden")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isEmailValid ? Color.blue : Color.gray)
                        .cornerRadius(25)
                    }
                    .disabled(!isEmailValid || isLoading)
                    .padding(.horizontal, 40)
                    
                    // Back to login
                    Button("Zurück zur Anmeldung") {
                        dismiss()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .alert("E-Mail gesendet!", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Falls ein Konto mit dieser E-Mail-Adresse existiert, wurde eine Passwort-Reset-E-Mail gesendet.")
        }
        .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    private func sendResetEmail() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await APIClient.shared.forgotPassword(email: email)
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
}
