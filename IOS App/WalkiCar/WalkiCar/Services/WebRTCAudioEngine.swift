//
//  WebRTCAudioEngine.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import AVFoundation
import WebRTC

@MainActor
class WebRTCAudioEngine: NSObject, ObservableObject {
    static let shared = WebRTCAudioEngine()
    
    // MARK: - Published Properties
    @Published var isMicrophoneEnabled = true
    @Published var isSpeakerEnabled = true
    @Published var audioLevel: Float = 0.0
    @Published var isConnected = false
    @Published var connectionError: String?
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioSession: AVAudioSession?
    
    // WebRTC Components
    private var peerConnectionFactory: RTCPeerConnectionFactory?
    var peerConnections: [Int: RTCPeerConnection] = [:]
    private var audioTracks: [Int: RTCAudioTrack] = [:]
    private var remoteAudioTracks: [Int: RTCAudioTrack] = [:]
    private var pendingIceCandidates: [Int: [RTCIceCandidate]] = [:]
    
    // Audio Configuration
    private let audioFormat = AVAudioFormat(
        standardFormatWithSampleRate: 48000,
        channels: 1
    )!
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupWebRTC()
        setupAudioEngine()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Audio Session für WebRTC Voice Chat optimieren
            try audioSession?.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .duckOthers,
                .interruptSpokenAudioAndMixWithOthers
            ])
            
            // Sample Rate und Buffer für Voice Chat optimieren
            try audioSession?.setPreferredSampleRate(48000.0) // Standard für Voice Chat
            try audioSession?.setPreferredIOBufferDuration(0.01) // 10ms Buffer für niedrige Latenz
            
            // Audio Session aktivieren
            try audioSession?.setActive(true)
            print("🎤 WebRTCAudioEngine: Audio Session konfiguriert")
            print("🔊 WebRTCAudioEngine: Audio Route: \(audioSession?.currentRoute.outputs.first?.portType.rawValue ?? "unbekannt")")
            print("🎤 WebRTCAudioEngine: Sample Rate: \(audioSession?.sampleRate ?? 0)")
            print("🎤 WebRTCAudioEngine: Buffer Duration: \(audioSession?.ioBufferDuration ?? 0)")
        } catch {
            print("❌ WebRTCAudioEngine: Audio Session Fehler: \(error)")
            connectionError = "Audio Session Fehler: \(error.localizedDescription)"
        }
    }
    
    // MARK: - WebRTC Setup
    private func setupWebRTC() {
        // Initialize WebRTC
        RTCInitializeSSL()
        
        // Create peer connection factory with audio support
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )
        
        print("🌐 WebRTCAudioEngine: WebRTC initialisiert")
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        inputNode = audioEngine.inputNode
        
        // Configure input node for microphone monitoring (nur für Audio Level)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, time in
            self?.processAudioInput(buffer: buffer, time: time)
        }
        
        print("🎵 WebRTCAudioEngine: Audio Engine konfiguriert (nur für Monitoring)")
        print("🎤 WebRTCAudioEngine: WebRTC Audio Source wird für tatsächliche Audio-Übertragung verwendet")
    }
    
    // MARK: - Public Methods
    
    func startAudio() {
        guard let audioEngine = audioEngine else { return }
        
        do {
            // Audio Session für WebRTC optimieren
            print("🔊 WebRTCAudioEngine: Konfiguriere Audio Session für WebRTC...")
            try audioSession?.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .duckOthers,
                .interruptSpokenAudioAndMixWithOthers
            ])
            
            // Audio Session aktivieren bevor Audio Engine startet
            print("🔊 WebRTCAudioEngine: Aktiviere Audio Session...")
            try audioSession?.setActive(true)
            print("✅ WebRTCAudioEngine: Audio Session aktiviert")
            
            try audioEngine.start()
            isConnected = true
            print("🎤 WebRTCAudioEngine: Audio gestartet")
            
            // Debug Audio Status
            debugAudioStatus()
        } catch {
            print("❌ WebRTCAudioEngine: Audio Start Fehler: \(error)")
            connectionError = "Audio Start Fehler: \(error.localizedDescription)"
            
            // Fallback: Versuche Audio Session trotzdem zu aktivieren
            do {
                try audioSession?.setActive(true)
                print("✅ WebRTCAudioEngine: Audio Session nach Fehler aktiviert")
            } catch {
                print("❌ WebRTCAudioEngine: Audio Session Aktivierung fehlgeschlagen: \(error)")
            }
        }
    }
    
    func stopAudio() {
        audioEngine?.stop()
        isConnected = false
        print("🔇 WebRTCAudioEngine: Audio gestoppt")
    }
    
    func debugAudioStatus() {
        guard let audioSession = audioSession else {
            print("❌ WebRTCAudioEngine: Keine Audio Session")
            return
        }
        
        print("🔊 WebRTCAudioEngine: Audio Status:")
        print("   - Category: \(audioSession.category.rawValue)")
        print("   - Mode: \(audioSession.mode.rawValue)")
        print("   - Other Audio Playing: \(audioSession.isOtherAudioPlaying)")
        print("   - Route: \(audioSession.currentRoute.outputs.map { $0.portType.rawValue })")
        print("   - Input Available: \(audioSession.isInputAvailable)")
        print("   - Output Available: \(audioSession.outputVolume)")
        print("   - Preferred Sample Rate: \(audioSession.preferredSampleRate)")
        print("   - Current Sample Rate: \(audioSession.sampleRate)")
        
        // Versuche Audio Session zu aktivieren falls sie nicht aktiv ist
        do {
            try audioSession.setActive(true)
            print("✅ WebRTCAudioEngine: Audio Session aktiviert")
            
            // Warte kurz und prüfe erneut
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔊 WebRTCAudioEngine: Audio Status nach Aktivierung:")
                print("   - Other Audio Playing: \(audioSession.isOtherAudioPlaying)")
                print("   - Route: \(audioSession.currentRoute.outputs.map { $0.portType.rawValue })")
                print("   - Sample Rate: \(audioSession.sampleRate)")
                
                // Versuche Audio Session erneut zu aktivieren
                do {
                    try audioSession.setActive(true)
                    print("✅ WebRTCAudioEngine: Audio Session erneut aktiviert")
                } catch {
                    print("❌ WebRTCAudioEngine: Audio Session Reaktivierung fehlgeschlagen: \(error)")
                }
            }
        } catch {
            print("❌ WebRTCAudioEngine: Audio Session Aktivierung fehlgeschlagen: \(error)")
        }
    }
    
    func toggleMicrophone() {
        isMicrophoneEnabled.toggle()
        
        // Enable/disable all audio tracks
        for (userId, audioTrack) in audioTracks {
            audioTrack.isEnabled = isMicrophoneEnabled
            print("🎤 WebRTCAudioEngine: Audio Track für User \(userId) \(isMicrophoneEnabled ? "aktiviert" : "deaktiviert")")
        }
        
        // Also control input node volume
        inputNode?.volume = isMicrophoneEnabled ? 1.0 : 0.0
        print("🎤 WebRTCAudioEngine: Mikrofon \(isMicrophoneEnabled ? "aktiviert" : "deaktiviert")")
    }
    
    func toggleSpeaker() {
        isSpeakerEnabled.toggle()
        do {
            try audioSession?.overrideOutputAudioPort(isSpeakerEnabled ? .speaker : .none)
            print("🔊 WebRTCAudioEngine: Lautsprecher \(isSpeakerEnabled ? "aktiviert" : "deaktiviert")")
        } catch {
            print("❌ WebRTCAudioEngine: Lautsprecher Fehler: \(error)")
        }
    }
    
    func setSpeakerMode(_ mode: AVAudioSession.PortOverride) {
        do {
            try audioSession?.overrideOutputAudioPort(mode)
            print("🔊 WebRTCAudioEngine: Lautsprecher Modus geändert: \(mode)")
        } catch {
            print("❌ WebRTCAudioEngine: Lautsprecher Modus Fehler: \(error)")
        }
    }
    
    // MARK: - WebRTC Peer Connection Management
    
    func createPeerConnection(for userId: Int, groupId: Int) -> RTCPeerConnection? {
        guard let factory = peerConnectionFactory else { return nil }
        
        let configuration = RTCConfiguration()
        
        // ICE Servers mit TURN Server
        configuration.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
            // TURN Server für Internet-Verbindungen
            RTCIceServer(
                urlStrings: ["turn:walkcar.timrmp.de:3478"],
                username: "walkcar",
                credential: "walkcar123"
            ),
            // TURN Server mit TLS
            RTCIceServer(
                urlStrings: ["turns:walkcar.timrmp.de:5349"],
                username: "walkcar",
                credential: "walkcar123"
            )
        ]
        configuration.sdpSemantics = .unifiedPlan
        configuration.bundlePolicy = .maxBundle
        configuration.rtcpMuxPolicy = .require
        configuration.tcpCandidatePolicy = .enabled
        configuration.candidateNetworkPolicy = .all
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: [
                "DtlsSrtpKeyAgreement": "true"
            ]
        )
        
        let peerConnection = factory.peerConnection(with: configuration, constraints: constraints, delegate: self)
        
        // Audio Source mit Constraints für Audio-Aufnahme erstellen
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "googEchoCancellation": "true",
                "googAutoGainControl": "true",
                "googNoiseSuppression": "true",
                "googHighpassFilter": "true",
                "googTypingNoiseDetection": "true",
                "googAudioMirroring": "false"
            ],
            optionalConstraints: [
                "googAudioNetworkAdaptor": "true",
                "googAudioNetworkAdaptorConfig": "{\"minBitrateBps\":32000,\"maxBitrateBps\":128000}"
            ]
        )
        
        let audioSource = factory.audioSource(with: audioConstraints)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio_\(userId)")
        
        print("🎤 WebRTCAudioEngine: Audio Source erstellt mit Echo Cancellation und Noise Suppression")
        
        // Audio Track speichern und initialisieren
        audioTrack.isEnabled = isMicrophoneEnabled
        audioTracks[userId] = audioTrack
        
        // Mit Unified Plan: Audio Track direkt zur Peer Connection hinzufügen
        peerConnection?.add(audioTrack, streamIds: ["stream_\(groupId)"])
        
        print("🌐 WebRTCAudioEngine: Peer Connection erstellt für User \(userId) mit Audio Source")
        
        peerConnections[userId] = peerConnection
        return peerConnection
    }
    
    func removePeerConnection(for userId: Int) {
        peerConnections[userId]?.close()
        peerConnections.removeValue(forKey: userId)
        audioTracks.removeValue(forKey: userId)
        remoteAudioTracks.removeValue(forKey: userId)
        pendingIceCandidates.removeValue(forKey: userId)
        print("🌐 WebRTCAudioEngine: Peer Connection entfernt für User \(userId)")
    }
    
    func createOffer(for userId: Int, groupId: Int, completion: @escaping (RTCSessionDescription?) -> Void) {
        guard let peerConnection = peerConnections[userId] else {
            completion(nil)
            return
        }
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )
        
        peerConnection.offer(for: constraints) { [weak self] sdp, error in
            if let error = error {
                print("❌ WebRTCAudioEngine: Offer Fehler: \(error)")
                completion(nil)
                return
            }
            
            guard let sdp = sdp else {
                completion(nil)
                return
            }
            
            self?.peerConnections[userId]?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("❌ WebRTCAudioEngine: Set Local Description Fehler: \(error)")
                    completion(nil)
                } else {
                    print("🌐 WebRTCAudioEngine: Offer erstellt für User \(userId)")
                    completion(sdp)
                }
            }
        }
    }
    
    func createAnswer(for userId: Int, offer: RTCSessionDescription, completion: @escaping (RTCSessionDescription?) -> Void) {
        guard let peerConnection = peerConnections[userId] else {
            completion(nil)
            return
        }
        
        peerConnection.setRemoteDescription(offer) { [weak self] error in
            if let error = error {
                print("❌ WebRTCAudioEngine: Set Remote Description Fehler: \(error)")
                completion(nil)
                return
            }
            
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: [
                    "OfferToReceiveAudio": "true",
                    "OfferToReceiveVideo": "false"
                ],
                optionalConstraints: nil
            )
            
            self?.peerConnections[userId]?.answer(for: constraints) { sdp, error in
                if let error = error {
                    print("❌ WebRTCAudioEngine: Answer Fehler: \(error)")
                    completion(nil)
                    return
                }
                
                guard let sdp = sdp else {
                    completion(nil)
                    return
                }
                
                self?.peerConnections[userId]?.setLocalDescription(sdp) { error in
                    if let error = error {
                        print("❌ WebRTCAudioEngine: Set Local Description Fehler: \(error)")
                        completion(nil)
                    } else {
                        print("🌐 WebRTCAudioEngine: Answer erstellt für User \(userId)")
                        
                        // Process pending ICE candidates
                        self?.processPendingIceCandidates(for: userId)
                        
                        completion(sdp)
                    }
                }
            }
        }
    }
    
    func addIceCandidate(for userId: Int, candidate: RTCIceCandidate) {
        guard let peerConnection = peerConnections[userId] else {
            print("❌ WebRTCAudioEngine: Keine Peer Connection für User \(userId)")
            return
        }
        
        // Check if remote description is set
        if peerConnection.remoteDescription != nil {
            // Remote description is set, add ICE candidate immediately
            peerConnection.add(candidate) { error in
                if let error = error {
                    print("❌ WebRTCAudioEngine: ICE Candidate Fehler: \(error)")
                } else {
                    print("🌐 WebRTCAudioEngine: ICE Candidate hinzugefügt für User \(userId)")
                }
            }
        } else {
            // Remote description not set yet, queue the ICE candidate
            if pendingIceCandidates[userId] == nil {
                pendingIceCandidates[userId] = []
            }
            pendingIceCandidates[userId]?.append(candidate)
            print("🌐 WebRTCAudioEngine: ICE Candidate für User \(userId) in Warteschlange (Remote Description noch nicht gesetzt)")
        }
    }
    
    private func processPendingIceCandidates(for userId: Int) {
        guard let peerConnection = peerConnections[userId],
              let pendingCandidates = pendingIceCandidates[userId] else {
            return
        }
        
        print("🌐 WebRTCAudioEngine: Verarbeite \(pendingCandidates.count) wartende ICE Candidates für User \(userId)")
        
        for candidate in pendingCandidates {
            peerConnection.add(candidate) { error in
                if let error = error {
                    print("❌ WebRTCAudioEngine: ICE Candidate Fehler: \(error)")
                } else {
                    print("🌐 WebRTCAudioEngine: ICE Candidate hinzugefügt für User \(userId)")
                }
            }
        }
        
        // Clear pending candidates
        pendingIceCandidates[userId] = nil
    }
    
    private func loadTurnCredentials(completion: @escaping ([RTCIceServer]) -> Void) {
        guard let token = APIClient.shared.getAuthToken() else {
            print("❌ WebRTCAudioEngine: Kein Auth Token für TURN Credentials")
            completion([])
            return
        }
        
        var request = URLRequest(url: URL(string: "https://walkcar.timrmp.de/api/turn-credentials")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ WebRTCAudioEngine: TURN Credentials Fehler: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("❌ WebRTCAudioEngine: Keine TURN Credentials Daten")
                completion([])
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let iceServersData = json?["iceServers"] as? [[String: Any]] else {
                    print("❌ WebRTCAudioEngine: Ungültige TURN Credentials Antwort")
                    completion([])
                    return
                }
                
                var iceServers: [RTCIceServer] = []
                
                for serverData in iceServersData {
                    guard let urls = serverData["urls"] as? [String] else { continue }
                    
                    if let username = serverData["username"] as? String,
                       let credential = serverData["credential"] as? String {
                        // TURN Server mit Credentials
                        iceServers.append(RTCIceServer(
                            urlStrings: urls,
                            username: username,
                            credential: credential
                        ))
                    } else {
                        // STUN Server ohne Credentials
                        iceServers.append(RTCIceServer(urlStrings: urls))
                    }
                }
                
                print("🌐 WebRTCAudioEngine: TURN Credentials geladen - \(iceServers.count) Server")
                completion(iceServers)
                
            } catch {
                print("❌ WebRTCAudioEngine: TURN Credentials Parse Fehler: \(error)")
                completion([])
            }
        }.resume()
    }
    
    // MARK: - Audio Processing
    
    private func processAudioInput(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Calculate audio level für UI-Anzeige
        let audioLevel = calculateAudioLevel(buffer: buffer)
        DispatchQueue.main.async {
            self.audioLevel = audioLevel
        }
        
        // Audio wird automatisch von WebRTC Audio Source verarbeitet und übertragen
        // Die RTCAudioSource kümmert sich um die tatsächliche Audio-Übertragung
        if isMicrophoneEnabled && audioLevel > 0.01 {
            print("🎤 WebRTCAudioEngine: Audio Level: \(String(format: "%.3f", audioLevel)) - WebRTC übernimmt Übertragung")
        }
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        return sum / Float(frameLength)
    }
    
    
    // MARK: - Cleanup
    
    deinit {
        // Note: We can't use Task in deinit as it captures self
        // The audio will be cleaned up when the object is deallocated
        RTCShutdownInternalTracer()
        // Note: RTCShutdownSSL is not available in this WebRTC version
        // The SSL will be cleaned up automatically
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCAudioEngine: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("🌐 WebRTCAudioEngine: Signaling State geändert: \(stateChanged)")
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCIceConnectionState) {
        print("🌐 WebRTCAudioEngine: ICE Connection State geändert: \(stateChanged)")
        
        Task { @MainActor in
            self.isConnected = (stateChanged == .connected || stateChanged == .completed)
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCIceGatheringState) {
        print("🌐 WebRTCAudioEngine: ICE Gathering State geändert: \(stateChanged)")
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("🌐 WebRTCAudioEngine: ICE Candidate generiert")
        
        // Find the user ID for this peer connection
        Task { @MainActor in
            if let userId = self.peerConnections.first(where: { $0.value == peerConnection })?.key {
                // Send ICE candidate via WebSocket
                let candidateData: [String: Any] = [
                    "candidate": candidate.sdp,
                    "sdpMLineIndex": candidate.sdpMLineIndex,
                    "sdpMid": candidate.sdpMid ?? ""
                ]
                
                // Notify WebRTCPeerConnectionManager to send the candidate
                NotificationCenter.default.post(
                    name: NSNotification.Name("WebRTCIceCandidateGenerated"),
                    object: [
                        "userId": userId,
                        "candidate": candidateData
                    ]
                )
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("🌐 WebRTCAudioEngine: Media Stream hinzugefügt")
        
        // Handle remote audio tracks
        for audioTrack in stream.audioTracks {
            // Find the user ID for this peer connection
            Task { @MainActor in
                if let userId = self.peerConnections.first(where: { $0.value == peerConnection })?.key {
                    self.remoteAudioTracks[userId] = audioTrack
                    print("🎵 WebRTCAudioEngine: Remote Audio Track hinzugefügt für User \(userId)")
                }
            }
        }
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("🌐 WebRTCAudioEngine: Media Stream entfernt")
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        print("🌐 WebRTCAudioEngine: RTP Receiver hinzugefügt")
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove rtpReceiver: RTCRtpReceiver) {
        print("🌐 WebRTCAudioEngine: RTP Receiver entfernt")
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("🌐 WebRTCAudioEngine: ICE Candidates entfernt")
    }
    
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("🌐 WebRTCAudioEngine: Data Channel geöffnet")
    }
    
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🌐 WebRTCAudioEngine: Peer Connection sollte verhandeln")
    }
}
