//
//  VoiceChatView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import LiveKit

struct VoiceChatView: View {
  let group: Group
  @StateObject private var voiceViewModel = VoiceViewModel()
  @EnvironmentObject var audioManager: AudioRoutingManager
  @Environment(\.dismiss) private var dismiss
  
  @State private var isPressingPTT = false
  @State private var participants: [Participant] = []
  
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()
      
      VStack(spacing: 40) {
        // Header
        HStack {
          Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
              .font(.title2)
              .foregroundColor(.white)
          }
          
          Spacer()
          
          Text("Voice Chat")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
          
          Spacer()
          
          Button(action: { voiceViewModel.toggleMute() }) {
            Image(systemName: voiceViewModel.isMuted ? "mic.slash.fill" : "mic.fill")
              .font(.title2)
              .foregroundColor(voiceViewModel.isMuted ? .red : .green)
          }
        }
        .padding()
        
        // Microphone Icon
        VStack(spacing: 20) {
          ZStack {
            Circle()
              .fill(voiceViewModel.isConnected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
              .frame(width: 200, height: 200)
            
            Circle()
              .fill(voiceViewModel.isConnected ? Color.blue.opacity(0.6) : Color.gray.opacity(0.6))
              .frame(width: 150, height: 150)
            
            Image(systemName: "mic.fill")
              .font(.system(size: 60))
              .foregroundColor(voiceViewModel.isConnected ? .white : .gray)
          }
          .scaleEffect(isPressingPTT ? 1.1 : 1.0)
          .animation(.easeInOut(duration: 0.1), value: isPressingPTT)
        }
        
        // Participants List
        VStack(alignment: .leading, spacing: 12) {
          Text("Participants")
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal)
          
          ForEach(participants) { participant in
            ParticipantRowView(participant: participant)
          }
        }
        
        Spacer()
        
        // Push-to-Talk Button
        PushToTalkButton(
          isPressed: $isPressingPTT,
          onPress: {
            voiceViewModel.startTalking()
            audioManager.setVoiceActive(true)
          },
          onRelease: {
            voiceViewModel.stopTalking()
            audioManager.setVoiceActive(false)
          }
        )
        .padding(.bottom, 40)
      }
    }
    .onAppear {
      voiceViewModel.connectToGroup(groupId: group.id)
    }
    .onDisappear {
      voiceViewModel.disconnect()
    }
    .onChange(of: voiceViewModel.participants) { newParticipants in
      participants = newParticipants
    }
  }
}

struct ParticipantRowView: View {
  let participant: Participant
  
  var body: some View {
    HStack {
      Circle()
        .fill(participant.isSpeaking ? Color.green : Color.gray)
        .frame(width: 12, height: 12)
      
      Text(participant.name)
        .font(.body)
        .foregroundColor(.white)
      
      Spacer()
      
      if participant.isMuted {
        Image(systemName: "mic.slash.fill")
          .foregroundColor(.red)
      }
    }
    .padding(.horizontal)
  }
}

struct PushToTalkButton: View {
  @Binding var isPressed: Bool
  let onPress: () -> Void
  let onRelease: () -> Void
  
  var body: some View {
    Button(action: {}) {
      Text(isPressed ? "Talking..." : "Hold to Talk")
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(isPressed ? Color.red : Color.blue)
        .cornerRadius(30)
    }
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          if !isPressed {
            isPressed = true
            onPress()
          }
        }
        .onEnded { _ in
          if isPressed {
            isPressed = false
            onRelease()
          }
        }
    )
    .padding(.horizontal, 40)
  }
}

struct Participant: Identifiable {
  let id: String
  let name: String
  let isSpeaking: Bool
  let isMuted: Bool
}

class VoiceViewModel: ObservableObject {
  @Published var isConnected = false
  @Published var isMuted = true
  @Published var participants: [Participant] = []
  
  private var room: Room?
  private let apiService = APIService()
  private var cancellables = Set<AnyCancellable>()
  
  func connectToGroup(groupId: Int) {
    apiService.getVoiceToken(groupId: groupId)
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to get voice token: \(error)")
          }
        },
        receiveValue: { [weak self] voiceToken in
          self?.connectToRoom(token: voiceToken)
        }
      )
      .store(in: &cancellables)
  }
  
  private func connectToRoom(token: VoiceToken) {
    room = Room()
    
    room?.delegate = self
    
    Task {
      do {
        try await room?.connect(url: token.url, token: token.token)
        await MainActor.run {
          isConnected = true
        }
      } catch {
        print("Failed to connect to room: \(error)")
      }
    }
  }
  
  func disconnect() {
    Task {
      try? await room?.disconnect()
      await MainActor.run {
        isConnected = false
        participants = []
      }
    }
  }
  
  func toggleMute() {
    isMuted.toggle()
    // Implement actual mute/unmute logic with LiveKit
  }
  
  func startTalking() {
    isMuted = false
    // Implement actual talking logic with LiveKit
  }
  
  func stopTalking() {
    isMuted = true
    // Implement actual stop talking logic with LiveKit
  }
}

extension VoiceViewModel: RoomDelegate {
  func room(_ room: Room, participant: RemoteParticipant, didSubscribeToTrack track: Track, publication: TrackPublication) {
    // Handle track subscription
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeFromTrack track: Track, publication: TrackPublication) {
    // Handle track unsubscription
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didUpdateTrack track: Track, publication: TrackPublication) {
    // Handle track updates
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didUpdatePublication publication: TrackPublication, muted: Bool) {
    // Handle publication updates
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didUpdateConnectionState connectionState: ConnectionState) {
    // Handle connection state updates
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didUpdateSpeaking speaking: Bool) {
    // Update participant speaking state
    DispatchQueue.main.async {
      if let index = self.participants.firstIndex(where: { $0.id == participant.identity }) {
        self.participants[index] = Participant(
          id: participant.identity,
          name: participant.name ?? "Unknown",
          isSpeaking: speaking,
          isMuted: self.participants[index].isMuted
        )
      }
    }
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didUpdateMetadata metadata: String?) {
    // Handle metadata updates
  }
  
  func room(_ room: Room, didConnect isReconnect: Bool) {
    DispatchQueue.main.async {
      self.isConnected = true
    }
  }
  
  func room(_ room: Room, didDisconnect error: Error?) {
    DispatchQueue.main.async {
      self.isConnected = false
      self.participants = []
    }
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didJoin isReconnect: Bool) {
    DispatchQueue.main.async {
      let participant = Participant(
        id: participant.identity,
        name: participant.name ?? "Unknown",
        isSpeaking: false,
        isMuted: true
      )
      self.participants.append(participant)
    }
  }
  
  func room(_ room: Room, participant: RemoteParticipant, didLeave reason: ParticipantDisconnectReason?) {
    DispatchQueue.main.async {
      self.participants.removeAll { $0.id == participant.identity }
    }
  }
}

#Preview {
  VoiceChatView(group: Group(
    id: 1,
    name: "Test Group",
    description: "Test Description",
    isPublic: true,
    owner: User(id: 1, appleSub: "test", displayName: "Test User", avatarUrl: nil),
    memberCount: 3,
    createdAt: Date()
  ))
  .environmentObject(AudioRoutingManager())
}
