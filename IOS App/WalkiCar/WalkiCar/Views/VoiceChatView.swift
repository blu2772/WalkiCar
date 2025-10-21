//
//  VoiceChatView.swift
//  WalkiCar - Server-basierte Audio-Übertragung
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct VoiceChatView: View {
    @StateObject private var groupManager = GroupManager()
    @StateObject private var friendsManager = FriendsManager()
    @StateObject private var serverAudioEngine = ServerAudioEngine.shared
    @State private var showingCreateGroup = false
    @State private var isRecording = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Text("Voice Chat")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            showingCreateGroup = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Current Voice Chat Status
                    if groupManager.isInVoiceChat, let currentGroup = groupManager.currentVoiceChatGroup {
                        CurrentVoiceChatCard(
                            group: currentGroup,
                            isRecording: serverAudioEngine.isRecording,
                            audioLevel: serverAudioEngine.audioLevel,
                            isConnected: serverAudioEngine.isConnected,
                            onLeave: {
                                leaveVoiceChat(group: currentGroup)
                            },
                            onToggleMicrophone: {
                                serverAudioEngine.toggleMicrophone()
                            },
                            onToggleSpeaker: {
                                serverAudioEngine.toggleSpeaker()
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    // Groups List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(groupManager.groups) { group in
                                GroupVoiceChatCard(
                                    group: group,
                                    isInVoiceChat: groupManager.isInVoiceChat && groupManager.currentVoiceChatGroup?.id == group.id,
                                    onJoin: {
                                        joinVoiceChat(group: group)
                                    },
                                    onLeave: {
                                        leaveVoiceChat(group: group)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView(groupManager: groupManager, friendsManager: friendsManager)
        }
        .onAppear {
            groupManager.loadGroups()
        }
    }
    
    // MARK: - Voice Chat Actions
    
    private func joinVoiceChat(group: Group) {
        print("🎤 VoiceChatView: Trete Voice Chat bei für Gruppe \(group.id)")
        
        // Server-basierte Audio-Übertragung starten
        if let userId = AuthManager.shared.currentUser?.id {
            serverAudioEngine.startVoiceChat(groupId: group.id, userId: userId)
            groupManager.joinVoiceChat(group: group)
        }
    }
    
    private func leaveVoiceChat(group: Group) {
        print("🎤 VoiceChatView: Verlasse Voice Chat für Gruppe \(group.id)")
        
        // Server-basierte Audio-Übertragung stoppen
        serverAudioEngine.stopVoiceChat()
        groupManager.leaveVoiceChat(group: group)
    }
}

// MARK: - Current Voice Chat Card

struct CurrentVoiceChatCard: View {
    let group: Group
    let isRecording: Bool
    let audioLevel: Float
    let isConnected: Bool
    let onLeave: () -> Void
    let onToggleMicrophone: () -> Void
    let onToggleSpeaker: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Group Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Aktiver Voice Chat")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Connection Status
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(isConnected ? "Verbunden" : "Getrennt")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // Audio Level Indicator
            if isRecording {
                AudioLevelIndicator(level: audioLevel)
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                // Microphone Toggle
                Button(action: onToggleMicrophone) {
                    Image(systemName: isRecording ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isRecording ? .white : .red)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                
                // Leave Button
                Button(action: onLeave) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                
                // Speaker Toggle
                Button(action: onToggleSpeaker) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Audio Level Indicator

struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<10, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
            }
        }
        .frame(height: 20)
    }
    
    private func barColor(for index: Int) -> Color {
        let normalizedLevel = min(max(level * 10, 0), 1)
        let barIndex = Float(index)
        
        if barIndex < normalizedLevel * 10 {
            if index < 3 {
                return .green
            } else if index < 7 {
                return .yellow
            } else {
                return .red
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
        return heights[index]
    }
}

// MARK: - Group Voice Chat Card

struct GroupVoiceChatCard: View {
    let group: Group
    let isInVoiceChat: Bool
    let onJoin: () -> Void
    let onLeave: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(group.memberCount) Mitglieder")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isInVoiceChat {
                Button(action: onLeave) {
                    Text("Verlassen")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                }
            } else {
                Button(action: onJoin) {
                    Text("Beitreten")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    VoiceChatView()
}