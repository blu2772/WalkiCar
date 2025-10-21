//
//  ServerAudioEngine.swift
//  WalkiCar - Server-basierte Audio-Übertragung
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class ServerAudioEngine: NSObject, ObservableObject {
    static let shared = ServerAudioEngine()
    
    // MARK: - Published Properties
    @Published var isMicrophoneEnabled = true
    @Published var isSpeakerEnabled = true
    @Published var audioLevel: Float = 0.0
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published var isRecording = false
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioSession: AVAudioSession?
    private var webSocketManager: WebSocketManager?
    
    // Audio Configuration
    private let audioFormat = AVAudioFormat(
        standardFormatWithSampleRate: 48000,
        channels: 1
    )!
    
    // Audio Buffer für Server-Übertragung
    private var audioBuffer: [Float] = []
    private let bufferSize = 1024
    private let chunkSize = 1024 // Audio-Chunk-Größe
    
    // Current Voice Chat
    private var currentGroupId: Int?
    private var currentUserId: Int?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupAudioEngine()
        webSocketManager = WebSocketManager.shared
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try audioSession?.setActive(true)
            
            print("🎤 ServerAudioEngine: Audio Session konfiguriert")
            print("🔊 ServerAudioEngine: Audio Route: \(audioSession?.currentRoute.outputs.first?.portType.rawValue ?? "Unknown")")
            print("🎤 ServerAudioEngine: Sample Rate: \(audioSession?.sampleRate ?? 0)")
            print("🎤 ServerAudioEngine: Buffer Duration: \(audioSession?.ioBufferDuration ?? 0)")
        } catch {
            print("❌ ServerAudioEngine: Audio Session Setup Fehler: \(error)")
        }
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        inputNode = audioEngine.inputNode
        
        // Configure input node for microphone monitoring
        inputNode?.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: audioFormat) { [weak self] buffer, time in
            self?.processAudioInput(buffer: buffer, time: time)
        }
        
        print("🎵 ServerAudioEngine: Audio Engine konfiguriert für Server-Übertragung")
    }
    
    // MARK: - Public Methods
    
    func startVoiceChat(groupId: Int, userId: Int) {
        print("🎤 ServerAudioEngine: Starte Voice Chat für Gruppe \(groupId)")
        
        currentGroupId = groupId
        currentUserId = userId
        
        // Audio Session aktivieren
        activateAudioSession()
        
        // Audio Engine starten
        startAudio()
        
        // WebSocket Event Listener hinzufügen
        setupWebSocketListeners()
        
        isConnected = true
        isRecording = true
        
        print("✅ ServerAudioEngine: Voice Chat gestartet")
    }
    
    func stopVoiceChat() {
        print("🎤 ServerAudioEngine: Stoppe Voice Chat")
        
        stopAudio()
        deactivateAudioSession()
        
        // WebSocket Event Listener entfernen
        removeWebSocketListeners()
        
        isConnected = false
        isRecording = false
        currentGroupId = nil
        currentUserId = nil
        
        print("✅ ServerAudioEngine: Voice Chat gestoppt")
    }
    
    func activateAudioSession() {
        do {
            try audioSession?.setActive(true)
            print("✅ ServerAudioEngine: Audio Session aktiviert")
        } catch {
            print("❌ ServerAudioEngine: Audio Session Aktivierung fehlgeschlagen: \(error)")
        }
    }
    
    func deactivateAudioSession() {
        do {
            try audioSession?.setActive(false)
            print("🔇 ServerAudioEngine: Audio Session deaktiviert")
        } catch {
            print("❌ ServerAudioEngine: Audio Session Deaktivierung fehlgeschlagen: \(error)")
        }
    }
    
    func startAudio() {
        guard let audioEngine = audioEngine else { return }
        
        do {
            try audioEngine.start()
            print("🎤 ServerAudioEngine: Audio gestartet")
            
            // Audio Status loggen
            logAudioStatus()
        } catch {
            print("❌ ServerAudioEngine: Audio Start fehlgeschlagen: \(error)")
            connectionError = "Audio konnte nicht gestartet werden"
        }
    }
    
    func stopAudio() {
        audioEngine?.stop()
        print("🔇 ServerAudioEngine: Audio gestoppt")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioInput(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // Audio Level berechnen
        let audioLevel = calculateAudioLevel(channelData: channelData, frameCount: frameCount)
        
        DispatchQueue.main.async {
            self.audioLevel = audioLevel
        }
        
        // Audio-Daten für Server-Übertragung sammeln
        if isRecording && isMicrophoneEnabled {
            collectAudioForTransmission(channelData: channelData, frameCount: frameCount)
        }
    }
    
    private func calculateAudioLevel(channelData: UnsafeMutablePointer<Float>, frameCount: Int) -> Float {
        var sum: Float = 0.0
        for i in 0..<frameCount {
            sum += abs(channelData[i])
        }
        return sum / Float(frameCount)
    }
    
    private func collectAudioForTransmission(channelData: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Audio-Daten zu Buffer hinzufügen
        for i in 0..<frameCount {
            audioBuffer.append(channelData[i])
        }
        
        // Wenn Buffer voll ist, an Server senden
        if audioBuffer.count >= chunkSize {
            sendAudioChunkToServer()
        }
    }
    
    private func sendAudioChunkToServer() {
        guard let groupId = currentGroupId,
              let userId = currentUserId,
              audioBuffer.count >= chunkSize else { return }
        
        // Audio-Chunk extrahieren
        let chunk = Array(audioBuffer.prefix(chunkSize))
        audioBuffer.removeFirst(chunkSize)
        
        // Audio-Chunk an Server senden
        let audioData: [String: Any] = [
            "groupId": groupId,
            "audioData": chunk,
            "timestamp": Date().timeIntervalSince1970,
            "sampleRate": 48000,
            "channels": 1
        ]
        
        webSocketManager?.sendAudioChunk(groupId: groupId, audioData: chunk)
        
        print("📡 ServerAudioEngine: Audio-Chunk gesendet (\(chunk.count) Samples)")
    }
    
    // MARK: - WebSocket Event Handling
    
    private func setupWebSocketListeners() {
        // Audio-Daten vom Server empfangen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioData(_:)),
            name: NSNotification.Name("AudioDataReceived"),
            object: nil
        )
        
        // Voice Chat Events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserJoinedVoice(_:)),
            name: NSNotification.Name("UserJoinedVoiceChat"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserLeftVoice(_:)),
            name: NSNotification.Name("UserLeftVoiceChat"),
            object: nil
        )
    }
    
    private func removeWebSocketListeners() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAudioData(_ notification: Notification) {
        guard let audioPacket = notification.object as? [String: Any],
              let audioData = audioPacket["audioData"] as? [[String: Any]] else { return }
        
        // Audio-Daten verarbeiten und abspielen
        processReceivedAudio(audioData: audioData)
    }
    
    @objc private func handleUserJoinedVoice(_ notification: Notification) {
        print("🎤 ServerAudioEngine: User ist Voice Chat beigetreten")
    }
    
    @objc private func handleUserLeftVoice(_ notification: Notification) {
        print("🎤 ServerAudioEngine: User hat Voice Chat verlassen")
    }
    
    private func processReceivedAudio(audioData: [[String: Any]]) {
        // Audio-Daten von anderen Teilnehmern verarbeiten
        for audioChunk in audioData {
            guard let audioSamples = audioChunk["audioData"] as? [Float],
                  let fromUserId = audioChunk["userId"] as? Int else { continue }
            
            // Audio abspielen (vereinfacht - in echter App würde man Audio-Mixing machen)
            playAudioSamples(audioSamples)
        }
    }
    
    private func playAudioSamples(_ samples: [Float]) {
        // Vereinfachte Audio-Wiedergabe
        // In einer echten App würde man hier Audio-Mixing und -Wiedergabe implementieren
        print("🔊 ServerAudioEngine: Spiele Audio ab (\(samples.count) Samples)")
    }
    
    // MARK: - Audio Status Logging
    
    private func logAudioStatus() {
        guard let audioSession = audioSession else { return }
        
        print("🔊 ServerAudioEngine: Audio Status:")
        print("   - Category: \(audioSession.category.rawValue)")
        print("   - Mode: \(audioSession.mode.rawValue)")
        print("   - Other Audio Playing: \(audioSession.isOtherAudioPlaying)")
        print("   - Route: \(audioSession.currentRoute.outputs.map { $0.portType.rawValue })")
        print("   - Input Available: \(audioSession.isInputAvailable)")
        print("   - Output Available: \(audioSession.outputVolume)")
        print("   - Preferred Sample Rate: \(audioSession.preferredSampleRate)")
        print("   - Current Sample Rate: \(audioSession.sampleRate)")
    }
    
    // MARK: - Microphone Control
    
    func toggleMicrophone() {
        isMicrophoneEnabled.toggle()
        print("🎤 ServerAudioEngine: Mikrofon \(isMicrophoneEnabled ? "aktiviert" : "deaktiviert")")
    }
    
    func toggleSpeaker() {
        isSpeakerEnabled.toggle()
        
        do {
            if isSpeakerEnabled {
                try audioSession?.overrideOutputAudioPort(.speaker)
            } else {
                try audioSession?.overrideOutputAudioPort(.none)
            }
            print("🔊 ServerAudioEngine: Lautsprecher \(isSpeakerEnabled ? "aktiviert" : "deaktiviert")")
        } catch {
            print("❌ ServerAudioEngine: Lautsprecher-Toggle fehlgeschlagen: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Cleanup ohne Main Actor Aufruf
        audioEngine?.stop()
        print("🧹 ServerAudioEngine: Cleanup abgeschlossen")
    }
}
