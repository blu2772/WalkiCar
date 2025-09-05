//
//  WelcomeView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
  @EnvironmentObject var authManager: AuthManager
  @State private var isLoading = false
  
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()
      
      VStack(spacing: 40) {
        Spacer()
        
        VStack(spacing: 20) {
          Text("Welcome!")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
          
          Image("car-silver")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 200)
            .padding(.horizontal)
          
          Text("Sign in to connect with friends")
            .font(.headline)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
        }
        
        Spacer()
        
        SignInWithAppleButton(
          onRequest: { request in
            request.requestedScopes = [.fullName, .email]
          },
          onCompletion: { result in
            handleSignInResult(result)
          }
        )
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .cornerRadius(25)
        .padding(.horizontal, 40)
        .disabled(isLoading)
        
        Spacer()
      }
    }
  }
  
  private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .success(let authorization):
      if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
        authManager.signInWithApple(credential: appleIDCredential)
      }
    case .failure(let error):
      print("Sign in failed: \(error.localizedDescription)")
    }
  }
}

#Preview {
  WelcomeView()
    .environmentObject(AuthManager())
}
