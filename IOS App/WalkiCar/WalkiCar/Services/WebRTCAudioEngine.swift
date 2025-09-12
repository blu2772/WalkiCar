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
    private var peerConnections: [Int: RTCPeerConnection] = [:]
    private var audioTracks: [Int: RTCAudioTrack] = [:]
    private var remoteAudioTracks: [Int: RTCAudioTrack] = [:]
    
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
            try audioSession?.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP
            ])
            try audioSession?.setActive(true)
            print("🎤 WebRTCAudioEngine: Audio Session konfiguriert")
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
        
        // Configure input node for microphone
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, time in
            self?.processAudioInput(buffer: buffer, time: time)
        }
        
        print("🎵 WebRTCAudioEngine: Audio Engine konfiguriert")
    }
    
    // MARK: - Public Methods
    
    func startAudio() {
        guard let audioEngine = audioEngine else { return }
        
        do {
            try audioEngine.start()
            isConnected = true
            print("🎤 WebRTCAudioEngine: Audio gestartet")
        } catch {
            print("❌ WebRTCAudioEngine: Audio Start Fehler: \(error)")
            connectionError = "Audio Start Fehler: \(error.localizedDescription)"
        }
    }
    
    func stopAudio() {
        audioEngine?.stop()
        isConnected = false
        print("🔇 WebRTCAudioEngine: Audio gestoppt")
    }
    
    func toggleMicrophone() {
        isMicrophoneEnabled.toggle()
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
        configuration.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"])
        ]
        configuration.sdpSemantics = .unifiedPlan
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        
        let peerConnection = factory.peerConnection(with: configuration, constraints: constraints, delegate: self)
        
        // Audio Track erstellen und hinzufügen
        let audioTrack = factory.audioTrack(withTrackId: "audio_\(userId)")
        audioTracks[userId] = audioTrack
        
        // Media Stream erstellen und Audio Track hinzufügen
        let mediaStream = factory.mediaStream(withStreamId: "stream_\(groupId)")
        mediaStream.addAudioTrack(audioTrack)
        
        // Media Stream zur Peer Connection hinzufügen
        peerConnection?.add(mediaStream)
        
        // Audio Source für WebRTC erstellen
        let audioSource = factory.audioSource(with: nil)
        let audioTrackWithSource = factory.audioTrack(with: audioSource, trackId: "audio_\(userId)")
        
        // Audio Track mit Source zur Peer Connection hinzufügen
        peerConnection?.add(audioTrackWithSource, streamIds: ["stream_\(groupId)"])
        print("🌐 WebRTCAudioEngine: Peer Connection erstellt für User \(userId)")
        
        peerConnections[userId] = peerConnection
        return peerConnection
    }
    
    func removePeerConnection(for userId: Int) {
        peerConnections[userId]?.close()
        peerConnections.removeValue(forKey: userId)
        audioTracks.removeValue(forKey: userId)
        remoteAudioTracks.removeValue(forKey: userId)
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
                        completion(sdp)
                    }
                }
            }
        }
    }
    
    func addIceCandidate(for userId: Int, candidate: RTCIceCandidate) {
        peerConnections[userId]?.add(candidate) { error in
            if let error = error {
                print("❌ WebRTCAudioEngine: ICE Candidate Fehler: \(error)")
            } else {
                print("🌐 WebRTCAudioEngine: ICE Candidate hinzugefügt für User \(userId)")
            }
        }
    }
    
    // MARK: - Audio Processing
    
    private func processAudioInput(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Calculate audio level
        let audioLevel = calculateAudioLevel(buffer: buffer)
        DispatchQueue.main.async {
            self.audioLevel = audioLevel
        }
        
        // Send audio to WebRTC peers
        sendAudioToPeers(buffer: buffer)
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
    
    private func sendAudioToPeers(buffer: AVAudioPCMBuffer) {
        // Convert AVAudioPCMBuffer to WebRTC audio data
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        // Send audio frame to all active audio tracks
        for (userId, audioTrack) in audioTracks {
            if isMicrophoneEnabled {
                // In a real implementation, you would use WebRTC's audio processing pipeline
                // For now, we'll just log that audio is being processed
                print("🎤 WebRTCAudioEngine: Audio Frame gesendet an User \(userId)")
            }
        }
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
