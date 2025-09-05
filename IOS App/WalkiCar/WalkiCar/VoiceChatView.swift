import SwiftUI
import Combine
import WebRTC

// MARK: - WebRTC Voice Chat Manager
class VoiceChatManager: NSObject, ObservableObject {
  @Published var isConnected = false
  @Published var participants: [Participant] = []
  @Published var isMuted = true
  @Published var isPressingPTT = false
  
  private var peerConnectionFactory: RTCPeerConnectionFactory
  private var peerConnections: [String: RTCPeerConnection] = [:]
  private var localAudioTrack: RTCAudioTrack?
  private var signalingClient: SignalingClient?
  
  override init() {
    // Initialize WebRTC
    RTCInitializeSSL()
    let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
    let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
    peerConnectionFactory = RTCPeerConnectionFactory(
      encoderFactory: videoEncoderFactory,
      decoderFactory: videoDecoderFactory
    )
    super.init()
  }
  
  deinit {
    // WebRTC cleanup - RTCShutdownSSL is not available in newer versions
    peerConnections.values.forEach { $0.close() }
  }
  
  func joinGroup(groupId: String) {
    signalingClient = SignalingClient(groupId: groupId)
    signalingClient?.delegate = self
    signalingClient?.connect()
  }
  
  func leaveGroup() {
    signalingClient?.disconnect()
    signalingClient = nil
    
    // Close all peer connections
    peerConnections.values.forEach { $0.close() }
    peerConnections.removeAll()
    
    participants.removeAll()
    isConnected = false
  }
  
  func toggleMute() {
    isMuted.toggle()
    localAudioTrack?.isEnabled = !isMuted
    
    if isMuted {
      signalingClient?.sendMute()
    } else {
      signalingClient?.sendUnmute()
    }
  }
  
  func startPTT() {
    isPressingPTT = true
    isMuted = false
    localAudioTrack?.isEnabled = true
    signalingClient?.sendUnmute()
  }
  
  func endPTT() {
    isPressingPTT = false
    isMuted = true
    localAudioTrack?.isEnabled = false
    signalingClient?.sendMute()
  }
  
  private func createPeerConnection(for userId: String) -> RTCPeerConnection {
    let configuration = RTCConfiguration()
    configuration.iceServers = [
      RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
      RTCIceServer(
        urlStrings: ["turn:localhost:3478"],
        username: "turnuser",
        credential: "turnpassword"
      )
    ]
    
    let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    
    guard let peerConnection = peerConnectionFactory.peerConnection(with: configuration, constraints: constraints, delegate: self) else {
      fatalError("Failed to create peer connection")
    }
    
    // Add local audio track
    if localAudioTrack == nil {
      let audioSource = peerConnectionFactory.audioSource(with: nil)
      localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "ARDAMSAudioTrack")
    }
    
    if let audioTrack = localAudioTrack {
      peerConnection.add(audioTrack, streamIds: ["ARDAMS"])
    }
    
    return peerConnection
  }
}

// MARK: - Signaling Client
class SignalingClient: NSObject {
  private var webSocket: URLSessionWebSocketTask?
  private let groupId: String
  weak var delegate: SignalingClientDelegate?
  
  init(groupId: String) {
    self.groupId = groupId
    super.init()
  }
  
  func connect() {
    guard let url = URL(string: "ws://localhost:3000/voice") else { return }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer your-jwt-token", forHTTPHeaderField: "Authorization")
    
    webSocket = URLSession.shared.webSocketTask(with: request)
    webSocket?.resume()
    
    receiveMessage()
    
    // Join room
    sendMessage(type: "join-room", data: ["groupId": groupId])
  }
  
  func disconnect() {
    sendMessage(type: "leave-room", data: ["groupId": groupId])
    webSocket?.cancel()
    webSocket = nil
  }
  
  func sendMessage(type: String, data: [String: Any]) {
    let message: [String: Any] = [
      "type": type,
      "data": data
    ]
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
          let jsonString = String(data: jsonData, encoding: .utf8) else { return }
    
    webSocket?.send(.string(jsonString)) { error in
      if let error = error {
        print("❌ WebSocket send error: \(error)")
      }
    }
  }
  
  func sendWebRTCSignaling(type: String, data: [String: Any], targetUserId: String) {
    let message: [String: Any] = [
      "type": "webrtc-signaling",
      "data": [
        "type": type,
        "data": data,
        "targetUserId": targetUserId
      ]
    ]
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
          let jsonString = String(data: jsonData, encoding: .utf8) else { return }
    
    webSocket?.send(.string(jsonString)) { error in
      if let error = error {
        print("❌ WebRTC signaling error: \(error)")
      }
    }
  }
  
  func sendMute() {
    sendMessage(type: "mute", data: ["groupId": groupId])
  }
  
  func sendUnmute() {
    sendMessage(type: "unmute", data: ["groupId": groupId])
  }
  
  private func receiveMessage() {
    webSocket?.receive { [weak self] result in
      switch result {
      case .success(let message):
        switch message {
        case .string(let text):
          self?.handleMessage(text)
        case .data(let data):
          if let text = String(data: data, encoding: .utf8) {
            self?.handleMessage(text)
          }
        @unknown default:
          break
        }
        self?.receiveMessage()
      case .failure(let error):
        print("❌ WebSocket receive error: \(error)")
      }
    }
  }
  
  private func handleMessage(_ text: String) {
    guard let data = text.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    
    DispatchQueue.main.async {
      self.delegate?.signalingClient(self, didReceiveMessage: json)
    }
  }
}

// MARK: - Signaling Client Delegate
protocol SignalingClientDelegate: AnyObject {
  func signalingClient(_ client: SignalingClient, didReceiveMessage message: [String: Any])
}

extension VoiceChatManager: SignalingClientDelegate {
  func signalingClient(_ client: SignalingClient, didReceiveMessage message: [String: Any]) {
    guard let type = message["type"] as? String else { return }
    
    switch type {
    case "participants-list":
      if let participantsData = message["participants"] as? [[String: Any]] {
        participants = participantsData.compactMap { data in
          guard let userId = data["userId"] as? String else { return nil }
          return Participant(
            id: userId,
            name: "User \(userId)",
            isMuted: data["isMuted"] as? Bool ?? true
          )
        }
      }
      
    case "participant-joined":
      if let userId = message["userId"] as? String {
        let participant = Participant(id: userId, name: "User \(userId)", isMuted: true)
        participants.append(participant)
        
        // Create peer connection
        let peerConnection = createPeerConnection(for: userId)
        peerConnections[userId] = peerConnection
        
        // Send offer
        sendOffer(to: userId)
      }
      
    case "participant-left":
      if let userId = message["userId"] as? String {
        participants.removeAll { $0.id == userId }
        peerConnections[userId]?.close()
        peerConnections.removeValue(forKey: userId)
      }
      
    case "participant-muted":
      if let userId = message["userId"] as? String {
        if let index = participants.firstIndex(where: { $0.id == userId }) {
          participants[index].isMuted = true
        }
      }
      
    case "participant-unmuted":
      if let userId = message["userId"] as? String {
        if let index = participants.firstIndex(where: { $0.id == userId }) {
          participants[index].isMuted = false
        }
      }
      
    case "webrtc-signaling":
      if let data = message["data"] as? [String: Any],
         let signalingType = data["type"] as? String,
         let signalingData = data["data"] as? [String: Any],
         let fromUserId = data["fromUserId"] as? String {
        
        handleWebRTCSignaling(type: signalingType, data: signalingData, fromUserId: fromUserId)
      }
      
    default:
      break
    }
  }
  
  private func sendOffer(to userId: String) {
    guard let peerConnection = peerConnections[userId] else { return }
    
    let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    
    peerConnection.offer(for: constraints) { [weak self] sdp, error in
      if let error = error {
        print("❌ Create offer error: \(error)")
        return
      }
      
      guard let sdp = sdp else { return }
      
      peerConnection.setLocalDescription(sdp) { error in
        if let error = error {
          print("❌ Set local description error: \(error)")
          return
        }
        
        let offerData = [
          "type": "offer",
          "sdp": sdp.sdp
        ]
        
        self?.signalingClient?.sendWebRTCSignaling(type: "offer", data: offerData, targetUserId: userId)
      }
    }
  }
  
  private func handleWebRTCSignaling(type: String, data: [String: Any], fromUserId: String) {
    guard let peerConnection = peerConnections[fromUserId] else { return }
    
    switch type {
    case "offer":
      if let sdpString = data["sdp"] as? String {
        let sdp = RTCSessionDescription(type: .offer, sdp: sdpString)
        peerConnection.setRemoteDescription(sdp) { [weak self] error in
          if let error = error {
            print("❌ Set remote description error: \(error)")
            return
          }
          
          self?.sendAnswer(to: fromUserId)
        }
      }
      
    case "answer":
      if let sdpString = data["sdp"] as? String {
        let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
        peerConnection.setRemoteDescription(sdp) { error in
          if let error = error {
            print("❌ Set remote description error: \(error)")
          }
        }
      }
      
    case "ice-candidate":
      if let candidateData = data["candidate"] as? [String: Any],
         let candidateString = candidateData["candidate"] as? String,
         let sdpMLineIndex = candidateData["sdpMLineIndex"] as? Int32,
         let sdpMid = candidateData["sdpMid"] as? String {
        
        let candidate = RTCIceCandidate(
          sdp: candidateString,
          sdpMLineIndex: sdpMLineIndex,
          sdpMid: sdpMid
        )
        
        peerConnection.add(candidate) { error in
          if let error = error {
            print("❌ Failed to add ICE candidate: \(error)")
          }
        }
      }
      
    default:
      break
    }
  }
  
  private func sendAnswer(to userId: String) {
    guard let peerConnection = peerConnections[userId] else { return }
    
    let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    
    peerConnection.answer(for: constraints) { [weak self] sdp, error in
      if let error = error {
        print("❌ Create answer error: \(error)")
        return
      }
      
      guard let sdp = sdp else { return }
      
      peerConnection.setLocalDescription(sdp) { error in
        if let error = error {
          print("❌ Set local description error: \(error)")
          return
        }
        
        let answerData = [
          "type": "answer",
          "sdp": sdp.sdp
        ]
        
        self?.signalingClient?.sendWebRTCSignaling(type: "answer", data: answerData, targetUserId: userId)
      }
    }
  }
}

// MARK: - WebRTC Peer Connection Delegate
extension VoiceChatManager: RTCPeerConnectionDelegate {
  func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
    print("📡 Signaling state changed: \(stateChanged)")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    print("📡 Stream added")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    print("📡 Stream removed")
  }
  
  func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    print("📡 Should negotiate")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
    print("📡 ICE connection state changed: \(newState)")
    
    DispatchQueue.main.async {
      self.isConnected = newState == .connected
    }
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
    print("📡 ICE gathering state changed: \(newState)")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
            let candidateData: [String: Any] = [
          "candidate": [
            "candidate": candidate.sdp,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? ""
          ]
        ]
    
    // Find the user ID for this peer connection
    if let userId = peerConnections.first(where: { $0.value == peerConnection })?.key {
      signalingClient?.sendWebRTCSignaling(type: "ice-candidate", data: candidateData, targetUserId: userId)
    }
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
    print("📡 ICE candidates removed")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
    print("📡 Data channel opened")
  }
}

// MARK: - Participant Model
struct Participant: Identifiable {
  let id: String
  let name: String
  var isMuted: Bool
}

// MARK: - Enhanced Voice Chat View
struct VoiceChatView: View {
  @StateObject private var voiceChatManager = VoiceChatManager()
  @EnvironmentObject var audioRoutingManager: AudioRoutingManager
  @State private var groupId = "sample-group"
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 30) {
          // Connection Status
          HStack {
            Circle()
              .fill(voiceChatManager.isConnected ? .green : .red)
              .frame(width: 12, height: 12)
            
            Text(voiceChatManager.isConnected ? "Connected" : "Disconnected")
              .font(.caption)
              .foregroundColor(.gray)
            
            Spacer()
            
            Text("\(voiceChatManager.participants.count) participants")
              .font(.caption)
              .foregroundColor(.gray)
          }
          .padding()
          
          // Participants List
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(voiceChatManager.participants) { participant in
                ParticipantRow(
                  participant: participant,
                  isLocalUser: false
                )
              }
              
              // Local user
              ParticipantRow(
                participant: Participant(
                  id: "local",
                  name: "You",
                  isMuted: voiceChatManager.isMuted
                ),
                isLocalUser: true
              )
            }
            .padding()
          }
          
          Spacer()
          
          // PTT Button
          Button(action: {}) {
            ZStack {
              Circle()
                .fill(voiceChatManager.isPressingPTT ? Color.blue : Color.blue.opacity(0.3))
                .frame(width: 120, height: 120)
                .scaleEffect(voiceChatManager.isPressingPTT ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: voiceChatManager.isPressingPTT)
              
              Image(systemName: voiceChatManager.isPressingPTT ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
            }
          }
          .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if pressing {
              voiceChatManager.startPTT()
              audioRoutingManager.startVoiceSession()
            } else {
              voiceChatManager.endPTT()
              audioRoutingManager.endVoiceSession()
            }
          }, perform: {})
          
          // Mute Toggle Button
          Button(action: {
            voiceChatManager.toggleMute()
          }) {
            HStack {
              Image(systemName: voiceChatManager.isMuted ? "mic.slash.fill" : "mic.fill")
              Text(voiceChatManager.isMuted ? "Unmute" : "Mute")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
          }
          
          Spacer()
        }
      }
      .navigationTitle("Voice Chat")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        voiceChatManager.joinGroup(groupId: groupId)
      }
      .onDisappear {
        voiceChatManager.leaveGroup()
      }
    }
  }
}

// MARK: - Participant Row
struct ParticipantRow: View {
  let participant: Participant
  let isLocalUser: Bool
  
  var body: some View {
    HStack {
      // Avatar
      Circle()
        .fill(isLocalUser ? .blue : .green)
        .frame(width: 40, height: 40)
        .overlay(
          Text(String(participant.name.prefix(1)))
            .font(.headline)
            .foregroundColor(.white)
        )
      
      VStack(alignment: .leading, spacing: 4) {
        Text(participant.name)
          .font(.headline)
          .foregroundColor(.white)
        
        HStack {
          Image(systemName: participant.isMuted ? "mic.slash.fill" : "mic.fill")
            .foregroundColor(participant.isMuted ? .red : .green)
            .font(.caption)
          
          Text(participant.isMuted ? "Muted" : "Speaking")
            .font(.caption)
            .foregroundColor(.gray)
        }
      }
      
      Spacer()
      
      if isLocalUser {
        Text("You")
          .font(.caption)
          .foregroundColor(.blue)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
}
