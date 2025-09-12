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
    private var outputNode: AVAudioOutputNode?
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
    
    private let webRTCFormat = RTCAudioFormat(
        sampleRate: 48000,
        numChannels: 1
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
        
        // Create peer connection factory
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
        outputNode = audioEngine.outputNode
        
        // Configure input node for microphone
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, time in
            self?.processAudioInput(buffer: buffer, time: time)
        }
        
        // Configure output node for speaker
        outputNode?.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, time in
            self?.processAudioOutput(buffer: buffer, time: time)
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
        outputNode?.volume = isSpeakerEnabled ? 1.0 : 0.0
        print("🔊 WebRTCAudioEngine: Lautsprecher \(isSpeakerEnabled ? "aktiviert" : "deaktiviert")")
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
        
        // Add audio track
        let audioTrack = factory.audioTrack(withTrackId: "audio_\(userId)")
        audioTracks[userId] = audioTrack
        
        let audioSender = peerConnection.add(audioTrack, streamIds: ["stream_\(groupId)"])
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
        peerConnections[userId]?.add(candidate)
        print("🌐 WebRTCAudioEngine: ICE Candidate hinzugefügt für User \(userId)")
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
    
    private func processAudioOutput(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Process received audio from WebRTC peers
        // This would be implemented with WebRTC audio rendering
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
        // This is a simplified implementation
        // In a real implementation, you would use WebRTC's audio processing pipeline
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopAudio()
        RTCShutdownInternalTracer()
        RTCShutdownSSL()
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCAudioEngine: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("🌐 WebRTCAudioEngine: Signaling State geändert: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCIceConnectionState) {
        print("🌐 WebRTCAudioEngine: ICE Connection State geändert: \(stateChanged)")
        
        DispatchQueue.main.async {
            self.isConnected = (stateChanged == .connected || stateChanged == .completed)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCIceGatheringState) {
        print("🌐 WebRTCAudioEngine: ICE Gathering State geändert: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("🌐 WebRTCAudioEngine: Media Stream hinzugefügt")
        
        // Handle remote audio tracks
        for audioTrack in stream.audioTracks {
            // Find the user ID for this peer connection
            if let userId = peerConnections.first(where: { $0.value == peerConnection })?.key {
                remoteAudioTracks[userId] = audioTrack
                print("🎵 WebRTCAudioEngine: Remote Audio Track hinzugefügt für User \(userId)")
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("🌐 WebRTCAudioEngine: Media Stream entfernt")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        print("🌐 WebRTCAudioEngine: RTP Receiver hinzugefügt")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove rtpReceiver: RTCRtpReceiver) {
        print("🌐 WebRTCAudioEngine: RTP Receiver entfernt")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("🌐 WebRTCAudioEngine: Data Channel geöffnet")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🌐 WebRTCAudioEngine: Peer Connection sollte verhandeln")
    }
}
