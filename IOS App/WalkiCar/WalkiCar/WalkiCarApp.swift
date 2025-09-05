import SwiftUI
import AuthenticationServices
import Combine

@main
struct WalkiCarApp: App {
  @StateObject private var authManager = AuthManager()
  @StateObject private var audioRoutingManager = AudioRoutingManager()
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(authManager)
        .environmentObject(audioRoutingManager)
    }
  }
}