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
  @Published var isConfigured = false
  
  private var audioSession = AVAudioSession.sharedInstance()
  private var cancellables = Set<AnyCancellable>()
  
  init() {
    configureAudioSession()
    setupAudioRouteChangeNotification()
  }
  
  // MARK: - Audio Session Configuration
  func configureAudioSession() {
    do {
      // Configure for play and record with voice chat mode
      try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .defaultToSpeaker])
      
      // Do NOT set .allowBluetooth or .allowBluetoothA2DP to prevent HFP switching
      // This ensures Spotify continues playing in full A2DP quality
      
      try audioSession.setActive(true)
      isConfigured = true
      print("🎵 Audio session configured for music priority mode")
      print("🎵 Options: .mixWithOthers, .defaultToSpeaker")
      print("🎵 NOT set: .allowBluetooth, .allowBluetoothA2DP")
    } catch {
      print("❌ Failed to configure audio session: \(error)")
      isConfigured = false
    }
  }
  
  // MARK: - Audio Mode Switching
  func setAudioMode(_ mode: AudioMode) {
    currentMode = mode
    
    do {
      switch mode {
      case .musicPriority:
        // Keep current configuration (no HFP)
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .defaultToSpeaker])
        print("🎵 Switched to music priority mode")
        print("🎵 Spotify will play in full A2DP quality")
        print("🎵 Voice chat will use iPhone speaker")
        
      case .handsFreePriority:
        // Allow Bluetooth HFP (with quality loss warning)
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        print("📞 Switched to hands-free priority mode")
        print("⚠️  Music quality may be reduced due to HFP")
        print("📞 Voice chat will use car hands-free system")
      }
      
      try audioSession.setActive(true)
    } catch {
      print("❌ Failed to set audio mode: \(error)")
    }
  }
  
  // MARK: - Voice Session Management
  func startVoiceSession() {
    isVoiceActive = true
    
    // Additional voice-specific configuration
    do {
      // Ensure audio session is active for voice
      try audioSession.setActive(true)
      
      // Set preferred sample rate for voice (16kHz is optimal for speech)
      try audioSession.setPreferredSampleRate(16000)
      
      // Set preferred buffer duration for low latency
      try audioSession.setPreferredIOBufferDuration(0.005) // 5ms
      
      print("🎙️ Voice session started")
      print("🎙️ Sample rate: 16kHz")
      print("🎙️ Buffer duration: 5ms")
    } catch {
      print("❌ Failed to configure voice session: \(error)")
    }
  }
  
  func endVoiceSession() {
    isVoiceActive = false
    
    // Cleanup voice-specific configuration
    do {
      // Reset to default sample rate
      try audioSession.setPreferredSampleRate(44100)
      
      // Reset to default buffer duration
      try audioSession.setPreferredIOBufferDuration(0.023) // 23ms
      
      print("🎙️ Voice session ended")
      print("🎙️ Reset to default audio settings")
    } catch {
      print("❌ Failed to reset voice session: \(error)")
    }
  }
  
  // MARK: - Audio Route Monitoring
  private func setupAudioRouteChangeNotification() {
    NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
      .sink { [weak self] notification in
        self?.handleAudioRouteChange(notification)
      }
      .store(in: &cancellables)
  }
  
  private func handleAudioRouteChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }
    
    switch reason {
    case .oldDeviceUnavailable:
      print("🔌 Audio device disconnected")
      // Handle device disconnection
      
    case .newDeviceAvailable:
      print("🔌 New audio device available")
      // Handle new device connection
      
    case .categoryChange:
      print("🔌 Audio category changed")
      // Handle category change
      
    case .override:
      print("🔌 Audio route override")
      // Handle route override
      
    case .wakeFromSleep:
      print("🔌 Audio session woke from sleep")
      // Reconfigure if needed
      
    case .noSuitableRouteForCategory:
      print("❌ No suitable route for current category")
      // Handle no suitable route
      
    case .routeConfigurationChange:
      print("🔌 Route configuration changed")
      // Handle configuration change
      
    case .unknown:
      print("🔌 Unknown audio route change")
      
    @unknown default:
      print("🔌 Unknown audio route change")
    }
  }
  
  // MARK: - Audio Quality Information
  func getCurrentAudioRoute() -> String {
    let currentRoute = audioSession.currentRoute
    let output = currentRoute.outputs.first
    
    switch output?.portType {
    case .builtInSpeaker:
      return "iPhone Speaker"
    case .builtInReceiver:
      return "iPhone Earpiece"
    case .bluetoothA2DP:
      return "Bluetooth (A2DP - High Quality)"
    case .bluetoothHFP:
      return "Bluetooth (HFP - Voice Quality)"
    case .bluetoothLE:
      return "Bluetooth LE"
    case .headphones:
      return "Wired Headphones"
    case .airPlay:
      return "AirPlay"
    case .usbAudio:
      return "USB Audio"
    case .carAudio:
      return "Car Audio"
    case .none:
      return "Unknown"
    @unknown default:
      return "Unknown"
    }
  }
  
  func getAudioQualityInfo() -> String {
    switch currentMode {
    case .musicPriority:
      return """
      🎵 Music Priority Mode
      • Spotify plays in full A2DP quality
      • Voice chat uses iPhone speaker
      • No quality loss for music
      • Optimal for music lovers
      """
      
    case .handsFreePriority:
      return """
      📞 Hands-Free Priority Mode
      • Voice chat uses car hands-free
      • Music may switch to HFP (lower quality)
      • Better for driving safety
      • Quality loss is documented
      """
    }
  }
  
  // MARK: - Debug Information
  func printAudioSessionInfo() {
    print("🎵 === Audio Session Info ===")
    print("🎵 Category: \(audioSession.category)")
    print("🎵 Mode: \(audioSession.mode)")
    print("🎵 Options: \(audioSession.categoryOptions)")
    print("🎵 Sample Rate: \(audioSession.sampleRate)")
    print("🎵 Buffer Duration: \(audioSession.ioBufferDuration)")
    print("🎵 Current Route: \(getCurrentAudioRoute())")
    print("🎵 Voice Active: \(isVoiceActive)")
    print("🎵 Current Mode: \(currentMode)")
    print("🎵 =========================")
  }
}

// MARK: - Audio Quality Monitor
class AudioQualityMonitor: ObservableObject {
  @Published var currentQuality: AudioQuality = .high
  @Published var isMonitoring = false
  
  enum AudioQuality {
    case high      // A2DP or wired
    case medium    // HFP or compressed
    case low       // Poor connection
  }
  
  private var audioSession = AVAudioSession.sharedInstance()
  private var timer: Timer?
  
  func startMonitoring() {
    isMonitoring = true
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.updateQuality()
    }
  }
  
  func stopMonitoring() {
    isMonitoring = false
    timer?.invalidate()
    timer = nil
  }
  
  private func updateQuality() {
    let currentRoute = audioSession.currentRoute
    let output = currentRoute.outputs.first
    
    switch output?.portType {
    case .bluetoothA2DP, .headphones, .usbAudio:
      currentQuality = .high
    case .bluetoothHFP, .carAudio:
      currentQuality = .medium
    case .builtInSpeaker, .builtInReceiver:
      currentQuality = .high
    case .none:
      currentQuality = .low
    @unknown default:
      currentQuality = .low
    }
  }
}

// MARK: - Audio Settings View
struct AudioSettingsView: View {
  @EnvironmentObject var audioRoutingManager: AudioRoutingManager
  @StateObject private var qualityMonitor = AudioQualityMonitor()
  @State private var showingInfo = false
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
          // Current Audio Route
          VStack(alignment: .leading, spacing: 12) {
            Text("Current Audio Route")
              .font(.headline)
              .foregroundColor(.white)
            
            HStack {
              Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.blue)
              
              Text(audioRoutingManager.getCurrentAudioRoute())
                .foregroundColor(.white)
              
              Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
          }
          
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
            
            // Mode Description
            Text(modeDescription(audioRoutingManager.currentMode))
              .font(.caption)
              .foregroundColor(.gray)
              .padding(.top, 4)
          }
          
          // Quality Monitor
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text("Audio Quality Monitor")
                .font(.headline)
              .foregroundColor(.white)
              
              Spacer()
              
              Button(qualityMonitor.isMonitoring ? "Stop" : "Start") {
                if qualityMonitor.isMonitoring {
                  qualityMonitor.stopMonitoring()
                } else {
                  qualityMonitor.startMonitoring()
                }
              }
              .foregroundColor(.blue)
            }
            
            HStack {
              Circle()
                .fill(qualityColor(qualityMonitor.currentQuality))
                .frame(width: 12, height: 12)
              
              Text(qualityText(qualityMonitor.currentQuality))
                .foregroundColor(.white)
              
              Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
          }
          
          // Debug Information
          Button("Show Audio Info") {
            showingInfo = true
          }
          .foregroundColor(.blue)
          .padding()
          .background(Color.blue.opacity(0.2))
          .cornerRadius(8)
          
          Spacer()
        }
        .padding()
      }
      .navigationTitle("Audio Settings")
      .navigationBarTitleDisplayMode(.inline)
      .alert("Audio Session Info", isPresented: $showingInfo) {
        Button("OK") { }
      } message: {
        Text(audioRoutingManager.getAudioQualityInfo())
      }
    }
  }
  
  private func modeDescription(_ mode: AudioRoutingManager.AudioMode) -> String {
    switch mode {
    case .musicPriority:
      return "Spotify plays in full quality, voice on iPhone speaker"
    case .handsFreePriority:
      return "Allows car hands-free, music quality may be reduced"
    }
  }
  
  private func qualityColor(_ quality: AudioQualityMonitor.AudioQuality) -> Color {
    switch quality {
    case .high: return .green
    case .medium: return .orange
    case .low: return .red
    }
  }
  
  private func qualityText(_ quality: AudioQualityMonitor.AudioQuality) -> String {
    switch quality {
    case .high: return "High Quality (A2DP/Wired)"
    case .medium: return "Medium Quality (HFP)"
    case .low: return "Low Quality (Poor Connection)"
    }
  }
}
