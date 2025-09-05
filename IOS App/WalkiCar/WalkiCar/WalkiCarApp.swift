//
//  WalkiCarApp.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

@main
struct WalkiCarApp: App {
  @StateObject private var authManager = AuthManager()
  @StateObject private var audioManager = AudioRoutingManager()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(authManager)
        .environmentObject(audioManager)
        .onAppear {
          configureAudioSession()
        }
    }
  }
  
  private func configureAudioSession() {
    audioManager.configureAudioSession()
  }
}