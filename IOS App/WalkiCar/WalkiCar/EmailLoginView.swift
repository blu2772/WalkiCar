import SwiftUI

struct EmailLoginView: View {
  @State private var email = ""
  @State private var password = ""
  @State private var isLoading = false
  @State private var errorMessage = ""
  @State private var showRegister = false
  
  @EnvironmentObject var authManager: AuthManager
  
  var body: some View {
    VStack(spacing: 20) {
      // Header
      VStack(spacing: 8) {
        Image(systemName: "car.fill")
          .font(.system(size: 60))
          .foregroundColor(.blue)
        
        Text("WalkiCar")
          .font(.largeTitle)
          .fontWeight(.bold)
        
        Text("Mit Email anmelden")
          .font(.headline)
          .foregroundColor(.secondary)
      }
      .padding(.top, 40)
      
      // Login Form
      VStack(spacing: 16) {
        // Email Field
        VStack(alignment: .leading, spacing: 4) {
          Text("Email")
            .font(.subheadline)
            .fontWeight(.medium)
          
          TextField("deine@email.com", text: $email)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
        
        // Password Field
        VStack(alignment: .leading, spacing: 4) {
          Text("Passwort")
            .font(.subheadline)
            .fontWeight(.medium)
          
          SecureField("Passwort", text: $password)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        // Error Message
        if !errorMessage.isEmpty {
          Text(errorMessage)
            .foregroundColor(.red)
            .font(.caption)
            .multilineTextAlignment(.center)
        }
        
        // Login Button
        Button(action: login) {
          HStack {
            if isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            }
            Text(isLoading ? "Anmelden..." : "Anmelden")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
          .foregroundColor(.white)
          .cornerRadius(10)
        }
        .disabled(email.isEmpty || password.isEmpty || isLoading)
        
        // Register Link
        HStack {
          Text("Noch kein Konto?")
            .foregroundColor(.secondary)
          
          Button("Registrieren") {
            showRegister = true
          }
          .foregroundColor(.blue)
        }
        .font(.subheadline)
      }
      .padding(.horizontal, 32)
      
      Spacer()
      
      // Apple Sign In Alternative
      VStack(spacing: 12) {
        Text("oder")
          .foregroundColor(.secondary)
          .font(.subheadline)
        
        Button(action: {
          // Switch to Apple Sign In
          authManager.showAppleSignIn = true
        }) {
          HStack {
            Image(systemName: "applelogo")
            Text("Mit Apple anmelden")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.black)
          .foregroundColor(.white)
          .cornerRadius(10)
        }
        .padding(.horizontal, 32)
      }
      .padding(.bottom, 40)
    }
    .sheet(isPresented: $showRegister) {
      EmailRegisterView()
        .environmentObject(authManager)
    }
  }
  
  private func login() {
    isLoading = true
    errorMessage = ""
    
    Task {
      do {
        try await authManager.signInWithEmail(email: email, password: password)
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isLoading = false
        }
      }
    }
  }
}

struct EmailRegisterView: View {
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var displayName = ""
  @State private var isLoading = false
  @State private var errorMessage = ""
  
  @EnvironmentObject var authManager: AuthManager
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        // Header
        VStack(spacing: 8) {
          Image(systemName: "person.badge.plus")
            .font(.system(size: 50))
            .foregroundColor(.blue)
          
          Text("Registrieren")
            .font(.title)
            .fontWeight(.bold)
        }
        .padding(.top, 20)
        
        // Register Form
        VStack(spacing: 16) {
          // Display Name Field
          VStack(alignment: .leading, spacing: 4) {
            Text("Anzeigename")
              .font(.subheadline)
              .fontWeight(.medium)
            
            TextField("Dein Name", text: $displayName)
              .textFieldStyle(RoundedBorderTextFieldStyle())
          }
          
          // Email Field
          VStack(alignment: .leading, spacing: 4) {
            Text("Email")
              .font(.subheadline)
              .fontWeight(.medium)
            
            TextField("deine@email.com", text: $email)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .keyboardType(.emailAddress)
              .autocapitalization(.none)
              .disableAutocorrection(true)
          }
          
          // Password Field
          VStack(alignment: .leading, spacing: 4) {
            Text("Passwort")
              .font(.subheadline)
              .fontWeight(.medium)
            
            SecureField("Passwort", text: $password)
              .textFieldStyle(RoundedBorderTextFieldStyle())
          }
          
          // Confirm Password Field
          VStack(alignment: .leading, spacing: 4) {
            Text("Passwort bestätigen")
              .font(.subheadline)
              .fontWeight(.medium)
            
            SecureField("Passwort wiederholen", text: $confirmPassword)
              .textFieldStyle(RoundedBorderTextFieldStyle())
          }
          
          // Error Message
          if !errorMessage.isEmpty {
            Text(errorMessage)
              .foregroundColor(.red)
              .font(.caption)
              .multilineTextAlignment(.center)
          }
          
          // Register Button
          Button(action: register) {
            HStack {
              if isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.8)
              }
              Text(isLoading ? "Registrieren..." : "Registrieren")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
          .disabled(!isFormValid || isLoading)
        }
        .padding(.horizontal, 32)
        
        Spacer()
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") {
            dismiss()
          }
        }
      }
    }
  }
  
  private var isFormValid: Bool {
    !email.isEmpty && 
    !password.isEmpty && 
    !confirmPassword.isEmpty && 
    !displayName.isEmpty &&
    password == confirmPassword &&
    password.count >= 8
  }
  
  private func register() {
    guard password == confirmPassword else {
      errorMessage = "Passwörter stimmen nicht überein"
      return
    }
    
    guard password.count >= 8 else {
      errorMessage = "Passwort muss mindestens 8 Zeichen lang sein"
      return
    }
    
    isLoading = true
    errorMessage = ""
    
    Task {
      do {
        try await authManager.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName
        )
        await MainActor.run {
          dismiss()
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

#Preview {
  EmailLoginView()
    .environmentObject(AuthManager())
}
