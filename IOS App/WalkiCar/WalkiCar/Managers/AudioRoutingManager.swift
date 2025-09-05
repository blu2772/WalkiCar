//
//  AudioRoutingManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import AVFoundation
import Combine

enum AudioRoutingMode {
  case musicPriority  // Standard: Spotify A2DP-Qualität, Voice über iPhone-Speaker
  case handsFreePriority  // Optional: HFP-Modus mit Qualitätsabfall bei Musik
}

class AudioRoutingManager: ObservableObject {
  @Published var currentMode: AudioRoutingMode = .musicPriority
  @Published var isVoiceActive = false
  @Published var isMuted = true
  
  private var audioSession = AVAudioSession.sharedInstance()
  
  func configureAudioSession() {
    do {
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.mixWithOthers, .defaultToSpeaker]
      )
      
      // WICHTIG: Keine Bluetooth-Optionen setzen, um HFP-Umschaltung zu verhindern
      // .allowBluetooth und .allowBluetoothA2DP werden NICHT gesetzt
      
      try audioSession.setActive(true)
      
      print("Audio session configured for music priority mode")
    } catch {
      print("Failed to configure audio session: \(error)")
    }
  }
  
  func switchToHandsFreeMode() {
    do {
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
      )
      
      currentMode = .handsFreePriority
      print("Switched to hands-free priority mode (HFP enabled)")
    } catch {
      print("Failed to switch to hands-free mode: \(error)")
    }
  }
  
  func switchToMusicMode() {
    do {
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.mixWithOthers, .defaultToSpeaker]
      )
      
      currentMode = .musicPriority
      print("Switched to music priority mode (A2DP preserved)")
    } catch {
      print("Failed to switch to music mode: \(error)")
    }
  }
  
  func setVoiceActive(_ active: Bool) {
    isVoiceActive = active
    
    if active {
      // Voice-Audio auf iPhone-Lautsprecher routen
      do {
        try audioSession.overrideOutputAudioPort(.speaker)
      } catch {
        print("Failed to route voice to speaker: \(error)")
      }
    }
  }
  
  func toggleMute() {
    isMuted.toggle()
    // Diese Funktion wird von der VoiceEngine aufgerufen
  }
  
  func getAudioRouteDescription() -> String {
    switch currentMode {
    case .musicPriority:
      return "Musik-Priorität: Spotify bleibt in A2DP-Qualität, Voice über iPhone-Speaker"
    case .handsFreePriority:
      return "Freisprech-Priorität: HFP-Modus aktiviert (Qualitätsabfall bei Musik möglich)"
    }
  }
}
