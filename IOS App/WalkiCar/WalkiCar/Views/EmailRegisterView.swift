//
//  EmailRegisterView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct EmailRegisterView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingSuccess = false
    @State private var showingError = false
    
    // Callback für Navigation zum Login
    let onShowLogin: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Registrieren")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Erstelle dein WalkiCar Konto")
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
                            
                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Benutzername")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                TextField("benutzername", text: $username)
                                    .textFieldStyle(EmailTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            // Display name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Anzeigename")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                TextField("Dein Name", text: $displayName)
                                    .textFieldStyle(EmailTextFieldStyle())
                            }
                            
                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Passwort")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                SecureField("Mindestens 8 Zeichen", text: $password)
                                    .textFieldStyle(EmailTextFieldStyle())
                            }
                            
                            // Confirm password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Passwort bestätigen")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                SecureField("Passwort wiederholen", text: $confirmPassword)
                                    .textFieldStyle(EmailTextFieldStyle())
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        // Register button
                        Button(action: register) {
                            Text("Registrieren")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isFormValid ? Color.blue : Color.gray)
                                .cornerRadius(25)
                        }
                        .disabled(!isFormValid || authManager.isLoading)
                        .padding(.horizontal, 40)
                        
                        // Login link
                        HStack {
                            Text("Bereits ein Konto?")
                                .foregroundColor(.gray)
                            
                            Button("Anmelden") {
                                dismiss()
                                onShowLogin()
                            }
                            .foregroundColor(.blue)
                        }
                        .font(.system(size: 14))
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Erfolgreich registriert!", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Dein Konto wurde erstellt. Bitte überprüfe deine E-Mails zur Verifizierung.")
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
    
    private var isFormValid: Bool {
        let valid = !email.isEmpty && 
        !username.isEmpty && 
        !displayName.isEmpty && 
        !password.isEmpty && 
        !confirmPassword.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
        
        print("🔍 Form-Validierung: email=\(!email.isEmpty), username=\(!username.isEmpty), displayName=\(!displayName.isEmpty), password=\(!password.isEmpty), confirmPassword=\(!confirmPassword.isEmpty), emailFormat=\(email.contains("@")), passwordLength=\(password.count >= 8), passwordsMatch=\(password == confirmPassword)")
        print("✅ Formular gültig: \(valid)")
        
        return valid
    }
    
    private func register() {
        Task {
            do {
                try await authManager.registerWithEmail(
                    email: email,
                    username: username,
                    displayName: displayName,
                    password: password
                )
                showingSuccess = true
            } catch {
                // Error wird bereits vom AuthManager gesetzt
            }
        }
    }
}

#Preview {
    EmailRegisterView(authManager: AuthManager.shared, onShowLogin: {})
}
