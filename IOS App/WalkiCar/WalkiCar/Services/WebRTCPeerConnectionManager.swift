//
//  WebRTCPeerConnectionManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import WebRTC

@MainActor
class WebRTCPeerConnectionManager: NSObject, ObservableObject {
    static let shared = WebRTCPeerConnectionManager()
    
    // MARK: - Published Properties
    @Published var activeConnections: [Int: ConnectionState] = [:]
    @Published var connectionError: String?
    
    // MARK: - Private Properties
    private let webSocketManager = WebSocketManager.shared
    private let audioEngine = WebRTCAudioEngine.shared
    private let apiClient = APIClient.shared
    
    // Connection tracking
    private var currentGroupId: Int?
    private var localUserId: Int?
    private var pendingOffers: [Int: RTCSessionDescription] = [:]
    private var pendingAnswers: [Int: RTCSessionDescription] = [:]
    
    // MARK: - Connection State
    enum ConnectionState {
        case connecting
        case connected
        case disconnected
        case failed
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupWebSocketListeners()
    }
    
    // MARK: - Public Methods
    
    func startVoiceChat(groupId: Int, userId: Int) {
        print("🎤 WebRTCPeerConnectionManager: Starte Voice Chat für Gruppe \(groupId)")
        
        currentGroupId = groupId
        localUserId = userId
        
        // Join user room for direct communication
        webSocketManager.joinUserRoom(userId: userId)
        
        // Create peer connections for all group members
        createPeerConnectionsForGroup(groupId: groupId, userId: userId)
        
        // Start audio engine
        audioEngine.startAudio()
    }
    
    func stopVoiceChat() {
        print("🎤 WebRTCPeerConnectionManager: Stoppe Voice Chat")
        
        // Stop audio engine
        audioEngine.stopAudio()
        
        // Close all peer connections
        for userId in activeConnections.keys {
            audioEngine.removePeerConnection(for: userId)
        }
        
        // Clear state
        activeConnections.removeAll()
        pendingOffers.removeAll()
        pendingAnswers.removeAll()
        currentGroupId = nil
        localUserId = nil
    }
    
    func addParticipant(userId: Int) {
        guard let groupId = currentGroupId,
              let localUserId = localUserId else { 
            print("❌ WebRTCPeerConnectionManager: Keine Gruppe oder User-ID für addParticipant")
            return 
        }
        
        // Prüfe ob bereits eine Verbindung existiert
        if activeConnections[userId] != nil {
            print("🎤 WebRTCPeerConnectionManager: Verbindung zu User \(userId) bereits vorhanden")
            return
        }
        
        print("🎤 WebRTCPeerConnectionManager: Füge Teilnehmer \(userId) hinzu")
        
        // Create peer connection for new participant
        if audioEngine.createPeerConnection(for: userId, groupId: groupId) != nil {
            activeConnections[userId] = .connecting
            
            // Create offer
            audioEngine.createOffer(for: userId, groupId: groupId) { [weak self] offer in
                guard let offer = offer else { 
                    print("❌ WebRTCPeerConnectionManager: Kein Offer erstellt für neuen Teilnehmer \(userId)")
                    return 
                }
                
                print("🎤 WebRTCPeerConnectionManager: Sende Offer an neuen Teilnehmer \(userId)")
                // Send offer via WebSocket
                self?.sendOffer(to: userId, offer: offer, groupId: groupId)
            }
        } else {
            print("❌ WebRTCPeerConnectionManager: Peer Connection für User \(userId) konnte nicht erstellt werden")
        }
    }
    
    func removeParticipant(userId: Int) {
        print("🎤 WebRTCPeerConnectionManager: Entferne Teilnehmer \(userId)")
        
        // Send end call signal
        if let groupId = currentGroupId {
            sendEndCall(to: userId, groupId: groupId)
        }
        
        // Remove peer connection
        audioEngine.removePeerConnection(for: userId)
        activeConnections.removeValue(forKey: userId)
    }
    
    // MARK: - Private Methods
    
    private func createPeerConnectionsForGroup(groupId: Int, userId: Int) {
        // This would typically fetch group members from the API
        // For now, we'll create connections as participants join
        print("🎤 WebRTCPeerConnectionManager: Erstelle Peer Connections für Gruppe \(groupId)")
    }
    
    private func setupWebSocketListeners() {
        // WebRTC Signaling Events
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WebRTCOffer"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let fromUserId = data["fromUserId"] as? Int,
                  let groupId = data["groupId"] as? Int,
                  let offerData = data["offer"] as? [String: Any] else { return }
            
            Task { @MainActor in
                self?.handleIncomingOffer(from: fromUserId, groupId: groupId, offerData: offerData)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WebRTCAnswer"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let fromUserId = data["fromUserId"] as? Int,
                  let groupId = data["groupId"] as? Int,
                  let answerData = data["answer"] as? [String: Any] else { return }
            
            Task { @MainActor in
                self?.handleIncomingAnswer(from: fromUserId, groupId: groupId, answerData: answerData)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WebRTCIceCandidate"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let fromUserId = data["fromUserId"] as? Int,
                  let groupId = data["groupId"] as? Int,
                  let candidateData = data["candidate"] as? [String: Any] else { return }
            
            Task { @MainActor in
                self?.handleIncomingIceCandidate(from: fromUserId, groupId: groupId, candidateData: candidateData)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WebRTCEndCall"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let fromUserId = data["fromUserId"] as? Int,
                  let groupId = data["groupId"] as? Int else { return }
            
            Task { @MainActor in
                self?.handleIncomingEndCall(from: fromUserId, groupId: groupId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("WebRTCIceCandidateGenerated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let userId = data["userId"] as? Int,
                  let candidateData = data["candidate"] as? [String: Any] else { return }
            
            Task { @MainActor in
                guard let groupId = self?.currentGroupId else { return }
                self?.handleGeneratedIceCandidate(userId: userId, candidateData: candidateData, groupId: groupId)
            }
        }
    }
    
    private func handleIncomingOffer(from userId: Int, groupId: Int, offerData: [String: Any]) {
        print("🎤 WebRTCPeerConnectionManager: Erhalte Offer von User \(userId)")
        
        guard let groupId = currentGroupId,
              let localUserId = localUserId else { 
            print("❌ WebRTCPeerConnectionManager: Keine Gruppe oder User-ID für Offer")
            return 
        }
        
        // Create peer connection if it doesn't exist
        if activeConnections[userId] == nil {
            print("🎤 WebRTCPeerConnectionManager: Erstelle Peer Connection für User \(userId)")
            if audioEngine.createPeerConnection(for: userId, groupId: groupId) != nil {
                activeConnections[userId] = .connecting
            } else {
                print("❌ WebRTCPeerConnectionManager: Peer Connection für User \(userId) konnte nicht erstellt werden")
                return
            }
        }
        
        // Create RTCSessionDescription from offer data
        guard let sdp = offerData["sdp"] as? String else { 
            print("❌ WebRTCPeerConnectionManager: Ungültige Offer-Daten - SDP fehlt")
            print("❌ WebRTCPeerConnectionManager: Offer-Daten: \(offerData)")
            return 
        }
        
        // Handle both string and integer type values
        let type: RTCSdpType
        if let typeString = offerData["type"] as? String {
            // Type is a string
            switch typeString {
            case "offer":
                type = .offer
            case "answer":
                type = .answer
            case "pranswer":
                type = .prAnswer
            default:
                print("❌ WebRTCPeerConnectionManager: Unbekannter SDP Typ (String): \(typeString)")
                return
            }
        } else if let typeInt = offerData["type"] as? Int {
            // Type is an integer (0=offer, 1=answer, 2=pranswer)
            switch typeInt {
            case 0:
                type = .offer
            case 1:
                type = .answer
            case 2:
                type = .prAnswer
            default:
                print("❌ WebRTCPeerConnectionManager: Unbekannter SDP Typ (Int): \(typeInt)")
                return
            }
        } else {
            print("❌ WebRTCPeerConnectionManager: Ungültige Offer-Daten - Type fehlt")
            print("❌ WebRTCPeerConnectionManager: Offer-Daten: \(offerData)")
            print("❌ WebRTCPeerConnectionManager: SDP: \(offerData["sdp"] ?? "nil")")
            print("❌ WebRTCPeerConnectionManager: Type: \(offerData["type"] ?? "nil")")
            return
        }
        
        let offer = RTCSessionDescription(type: type, sdp: sdp)
        
        // Create answer
        audioEngine.createAnswer(for: userId, offer: offer) { [weak self] answer in
            guard let answer = answer else { 
                print("❌ WebRTCPeerConnectionManager: Kein Answer erstellt für User \(userId)")
                return 
            }
            
            print("🎤 WebRTCPeerConnectionManager: Answer erstellt für User \(userId)")
            print("🎤 WebRTCPeerConnectionManager: Sende Answer an User \(userId)")
            // Send answer via WebSocket
            self?.sendAnswer(to: userId, answer: answer, groupId: groupId)
        }
    }
    
    private func handleIncomingAnswer(from userId: Int, groupId: Int, answerData: [String: Any]) {
        print("🎤 WebRTCPeerConnectionManager: Erhalte Answer von User \(userId)")
        
        // Create RTCSessionDescription from answer data
        guard let sdp = answerData["sdp"] as? String else { 
            print("❌ WebRTCPeerConnectionManager: Ungültige Answer-Daten - SDP fehlt")
            return 
        }
        
        // Handle both string and integer type values
        let type: RTCSdpType
        if let typeString = answerData["type"] as? String {
            // Type is a string
            switch typeString {
            case "offer":
                type = .offer
            case "answer":
                type = .answer
            case "pranswer":
                type = .prAnswer
            default:
                print("❌ WebRTCPeerConnectionManager: Unbekannter SDP Typ (String): \(typeString)")
                return
            }
        } else if let typeInt = answerData["type"] as? Int {
            // Type is an integer (0=offer, 1=answer, 2=pranswer)
            switch typeInt {
            case 0:
                type = .offer
            case 1:
                type = .answer
            case 2:
                type = .prAnswer
            default:
                print("❌ WebRTCPeerConnectionManager: Unbekannter SDP Typ (Int): \(typeInt)")
                return
            }
        } else {
            print("❌ WebRTCPeerConnectionManager: Ungültige Answer-Daten - Type fehlt")
            return
        }
        
        let answer = RTCSessionDescription(type: type, sdp: sdp)
        
        // Set remote description
        guard let peerConnection = audioEngine.peerConnections[userId] else {
            print("❌ WebRTCPeerConnectionManager: Keine Peer Connection für User \(userId)")
            return
        }
        
        peerConnection.setRemoteDescription(answer) { error in
            if let error = error {
                print("❌ WebRTCPeerConnectionManager: Set Remote Description Fehler: \(error)")
            } else {
                print("✅ WebRTCPeerConnectionManager: Answer verarbeitet für User \(userId)")
                // Update connection state
                DispatchQueue.main.async {
                    self.activeConnections[userId] = .connected
                }
            }
        }
    }
    
    private func handleIncomingIceCandidate(from userId: Int, groupId: Int, candidateData: [String: Any]) {
        print("🎤 WebRTCPeerConnectionManager: Erhalte ICE Candidate von User \(userId)")
        
        // Create RTCIceCandidate from candidate data
        guard let candidate = candidateData["candidate"] as? String,
              let sdpMLineIndex = candidateData["sdpMLineIndex"] as? Int32,
              let sdpMid = candidateData["sdpMid"] as? String else { 
            print("❌ WebRTCPeerConnectionManager: Ungültige ICE Candidate Daten")
            return 
        }
        
        let iceCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        
        // Add ICE candidate - this will be queued if remote description is not set yet
        audioEngine.addIceCandidate(for: userId, candidate: iceCandidate)
        print("✅ WebRTCPeerConnectionManager: ICE Candidate hinzugefügt für User \(userId)")
    }
    
    private func handleIncomingEndCall(from userId: Int, groupId: Int) {
        print("🎤 WebRTCPeerConnectionManager: Erhalte End Call von User \(userId)")
        
        // Remove participant
        removeParticipant(userId: userId)
    }
    
    private func handleGeneratedIceCandidate(userId: Int, candidateData: [String: Any], groupId: Int) {
        print("🎤 WebRTCPeerConnectionManager: Generiere ICE Candidate für User \(userId)")
        
        // Create RTCIceCandidate from candidate data
        guard let candidate = candidateData["candidate"] as? String,
              let sdpMLineIndex = candidateData["sdpMLineIndex"] as? Int32,
              let sdpMid = candidateData["sdpMid"] as? String else { return }
        
        let iceCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        
        // Send ICE candidate via WebSocket
        sendIceCandidate(to: userId, candidate: iceCandidate, groupId: groupId)
    }
    
    // MARK: - WebSocket Signaling
    
    private func sendOffer(to userId: Int, offer: RTCSessionDescription, groupId: Int) {
        guard let localUserId = localUserId else { return }
        
        let offerData: [String: Any] = [
            "fromUserId": localUserId,
            "targetUserId": userId,
            "groupId": groupId,
            "offer": [
                "type": offer.type.rawValue,
                "sdp": offer.sdp
            ]
        ]
        
        webSocketManager.socketClient?.emit("webrtc_offer", offerData)
        print("🎤 WebRTCPeerConnectionManager: Offer gesendet an User \(userId)")
    }
    
    private func sendAnswer(to userId: Int, answer: RTCSessionDescription, groupId: Int) {
        guard let localUserId = localUserId else { return }
        
        let answerData: [String: Any] = [
            "fromUserId": localUserId,
            "targetUserId": userId,
            "groupId": groupId,
            "answer": [
                "type": answer.type.rawValue,
                "sdp": answer.sdp
            ]
        ]
        
        webSocketManager.socketClient?.emit("webrtc_answer", answerData)
        print("🎤 WebRTCPeerConnectionManager: Answer gesendet an User \(userId)")
    }
    
    private func sendIceCandidate(to userId: Int, candidate: RTCIceCandidate, groupId: Int) {
        guard let localUserId = localUserId else { return }
        
        let candidateData: [String: Any] = [
            "fromUserId": localUserId,
            "targetUserId": userId,
            "groupId": groupId,
            "candidate": [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid ?? ""
            ]
        ]
        
        webSocketManager.socketClient?.emit("webrtc_ice_candidate", candidateData)
        print("🎤 WebRTCPeerConnectionManager: ICE Candidate gesendet an User \(userId)")
    }
    
    private func sendEndCall(to userId: Int, groupId: Int) {
        guard let localUserId = localUserId else { return }
        
        let endCallData: [String: Any] = [
            "fromUserId": localUserId,
            "targetUserId": userId,
            "groupId": groupId
        ]
        
        webSocketManager.socketClient?.emit("webrtc_end_call", endCallData)
        print("🎤 WebRTCPeerConnectionManager: End Call gesendet an User \(userId)")
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { @MainActor in
            stopVoiceChat()
        }
    }
}
