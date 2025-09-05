import SwiftUI
import AVFoundation
import Combine

// MARK: - Audio Routing Manager
class AudioRoutingManager: ObservableObject {
  enum AudioMode {
    case musicPriority    // Default: Spotify in full quality, Voice on iPhone speaker
    case handsFreePriority // Optional: Allow HFP, document quality loss
  }
  
  @Published var currentMode: AudioMode = .musicPriority
  @Published var isVoiceActive = false
  
  private var audioSession = AVAudioSession.sharedInstance()
  
  init() {
    configureAudioSession()
  }
  
  func configureAudioSession() {
    do {
      // Configure for play and record with voice chat mode
      try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .defaultToSpeaker])
      
      // Do NOT set .allowBluetooth or .allowBluetoothA2DP to prevent HFP switching
      
      try audioSession.setActive(true)
      print("🎵 Audio session configured for music priority mode")
    } catch {
      print("❌ Failed to configure audio session: \(error)")
    }
  }
  
  func setAudioMode(_ mode: AudioMode) {
    currentMode = mode
    
    do {
      switch mode {
      case .musicPriority:
        // Keep current configuration (no HFP)
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .defaultToSpeaker])
        print("🎵 Switched to music priority mode")
        
      case .handsFreePriority:
        // Allow Bluetooth HFP (with quality loss warning)
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        print("📞 Switched to hands-free priority mode (music quality may be reduced)")
      }
      
      try audioSession.setActive(true)
    } catch {
      print("❌ Failed to set audio mode: \(error)")
    }
  }
  
  func startVoiceSession() {
    isVoiceActive = true
    // Additional voice-specific configuration if needed
  }
  
  func endVoiceSession() {
    isVoiceActive = false
    // Cleanup voice-specific configuration if needed
  }
}

// MARK: - Auth Manager
class AuthManager: ObservableObject {
  @Published var isAuthenticated = false
  @Published var currentUser: User?
  
  private let apiService = APIService()
  
  func signInWithApple() {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]
    
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.performRequests()
  }
  
  func signOut() {
    isAuthenticated = false
    currentUser = nil
  }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthManager: ASAuthorizationControllerDelegate {
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let identityToken = appleIDCredential.identityToken,
          let identityTokenString = String(data: identityToken, encoding: .utf8) else {
      return
    }
    
    let loginRequest = LoginRequest(
      identityToken: identityTokenString,
      displayName: appleIDCredential.fullName?.formatted() ?? "User",
      avatarUrl: nil
    )
    
    Task {
      do {
        let response = try await apiService.signInWithApple(loginRequest)
        await MainActor.run {
          self.isAuthenticated = true
          self.currentUser = response.user
        }
      } catch {
        print("❌ Sign in failed: \(error)")
      }
    }
  }
  
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    print("❌ Apple Sign In failed: \(error)")
  }
}

// MARK: - Data Models
struct User: Codable {
  let id: Int
  let display_name: String
  let avatar_url: String?
}

struct LoginRequest: Codable {
  let identityToken: String
  let displayName: String?
  let avatarUrl: String?
}

struct AuthResponse: Codable {
  let accessToken: String
  let refreshToken: String
  let user: User
}

// MARK: - API Service
class APIService: ObservableObject {
  private let baseURL = "http://localhost:3000/api/v1"
  
  func signInWithApple(_ request: LoginRequest) async throws -> AuthResponse {
    guard let url = URL(string: "\(baseURL)/auth/apple") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
    
    return try JSONDecoder().decode(AuthResponse.self, from: data)
  }
}

enum APIError: Error {
  case invalidURL
  case invalidResponse
}

// MARK: - Main Content View
struct ContentView: View {
  @EnvironmentObject var authManager: AuthManager
  @EnvironmentObject var audioRoutingManager: AudioRoutingManager
  
  var body: some View {
    Group {
      if authManager.isAuthenticated {
        MainTabView()
      } else {
        WelcomeView()
      }
    }
  }
}

// MARK: - Welcome View (Sign In Screen)
struct WelcomeView: View {
  @EnvironmentObject var authManager: AuthManager
  
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      
      VStack(spacing: 40) {
        Spacer()
        
        // Welcome Text
        Text("Welcome!")
          .font(.largeTitle)
          .fontWeight(.bold)
          .foregroundColor(.white)
        
        // Car Image (placeholder)
        Image(systemName: "car.fill")
          .font(.system(size: 120))
          .foregroundColor(.gray)
          .padding()
        
        // Sign in text
        Text("Sign in to connect with friends")
          .font(.headline)
          .foregroundColor(.white)
          .multilineTextAlignment(.center)
        
        Spacer()
        
        // Sign in with Apple button
        SignInWithAppleButton(.signIn) { request in
          // Request setup handled by AuthManager
        } onCompletion: { result in
          // Completion handled by AuthManager delegate
        }
        .frame(height: 50)
        .cornerRadius(25)
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
      }
    }
  }
}

// MARK: - Main Tab View
struct MainTabView: View {
  @EnvironmentObject var audioRoutingManager: AudioRoutingManager
  
  var body: some View {
    TabView {
      MapView()
        .tabItem {
          Image(systemName: "map")
          Text("Map")
        }
      
      VoiceChatView()
        .tabItem {
          Image(systemName: "mic")
          Text("Voice")
        }
      
      GarageView()
        .tabItem {
          Image(systemName: "car")
          Text("Garage")
        }
      
      FriendsView()
        .tabItem {
          Image(systemName: "person.2")
          Text("Friends")
        }
      
      SettingsView()
        .tabItem {
          Image(systemName: "gear")
          Text("Settings")
        }
    }
    .accentColor(.white)
    .preferredColorScheme(.dark)
  }
}




// MARK: - Settings View
struct SettingsView: View {
  @EnvironmentObject var audioRoutingManager: AudioRoutingManager
  @EnvironmentObject var authManager: AuthManager
  @State private var showingAudioSettings = false
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
          // Audio Mode Selection
          VStack(alignment: .leading, spacing: 12) {
            Text("Audio Mode")
              .font(.headline)
              .foregroundColor(.white)
            
            Picker("Audio Mode", selection: $audioRoutingManager.currentMode) {
              Text("Music Priority").tag(AudioRoutingManager.AudioMode.musicPriority)
              Text("Hands-Free Priority").tag(AudioRoutingManager.AudioMode.handsFreePriority)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: audioRoutingManager.currentMode) { newMode in
              audioRoutingManager.setAudioMode(newMode)
            }
            
            Text("Music Priority: Spotify plays in full quality, voice on iPhone speaker")
              .font(.caption)
              .foregroundColor(.gray)
            
            Text("Hands-Free Priority: Allows car hands-free, music quality may be reduced")
              .font(.caption)
              .foregroundColor(.gray)
          }
          .padding()
          
          // Audio Settings Button
          Button("Advanced Audio Settings") {
            showingAudioSettings = true
          }
          .foregroundColor(.blue)
          .padding()
          .background(Color.blue.opacity(0.2))
          .cornerRadius(8)
          
          Spacer()
          
          // Sign Out Button
          Button("Sign Out") {
            authManager.signOut()
          }
          .foregroundColor(.red)
          .padding()
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showingAudioSettings) {
        AudioSettingsView()
      }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(AuthManager())
    .environmentObject(AudioRoutingManager())
}