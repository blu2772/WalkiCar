//
//  ContentView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            authManager.checkAuthenticationStatus()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
