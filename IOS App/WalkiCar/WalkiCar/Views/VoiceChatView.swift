//
//  VoiceChatView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct VoiceChatView: View {
    @StateObject private var groupManager = GroupManager()
    @StateObject private var friendsManager = FriendsManager()
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
                            participants: groupManager.voiceChatParticipants,
                            isAudioConnected: groupManager.isAudioConnected,
                            audioLevel: groupManager.audioLevel,
                            onLeave: {
                                groupManager.leaveVoiceChat(groupId: currentGroup.id)
                            },
                            onToggleMicrophone: {
                                groupManager.toggleMicrophone()
                            },
                            onToggleSpeaker: {
                                groupManager.toggleSpeaker()
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
                                    onJoin: {
                                        groupManager.joinVoiceChat(groupId: group.id)
                                    },
                                    onLeave: {
                                        groupManager.leaveVoiceChat(groupId: group.id)
                                    }
                                )
                            }
                            
                            if groupManager.groups.isEmpty && !groupManager.isLoading {
                                EmptyGroupsView {
                                    showingCreateGroup = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView(
                groupManager: groupManager,
                friendsManager: friendsManager
            )
        }
        .onAppear {
            groupManager.loadGroups()
        }
    }
}

struct CurrentVoiceChatCard: View {
    let group: Group
    let participants: [VoiceChatParticipant]
    let isAudioConnected: Bool
    let audioLevel: Float
    let onLeave: () -> Void
    let onToggleMicrophone: () -> Void
    let onToggleSpeaker: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktiver Voice Chat")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Audio Connection Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isAudioConnected ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text(isAudioConnected ? "Audio verbunden" : "Audio getrennt")
                            .font(.caption2)
                            .foregroundColor(isAudioConnected ? .green : .red)
                    }
                }
                
                Spacer()
                
                Button(action: onLeave) {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.down.fill")
                        Text("Verlassen")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Audio Controls
            HStack(spacing: 20) {
                // Microphone Button
                Button(action: onToggleMicrophone) {
                    VStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Mikrofon")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                // Audio Level Indicator
                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 4, height: 30)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: 4, height: CGFloat(audioLevel) * 30)
                            .animation(.easeInOut(duration: 0.1), value: audioLevel)
                    }
                    
                    Text("Level")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // Speaker Button
                Button(action: onToggleSpeaker) {
                    VStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Lautsprecher")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Participants
            VStack(alignment: .leading, spacing: 8) {
                Text("Teilnehmer (\(participants.count))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                ForEach(participants) { participant in
                    HStack {
                        AsyncImage(url: URL(string: participant.profilePictureUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray)
                                .overlay(
                                    Text(String(participant.displayName.prefix(1)))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        
                        Text(participant.displayName)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
        )
    }
}

struct GroupVoiceChatCard: View {
    let group: Group
    let onJoin: () -> Void
    let onLeave: () -> Void
    
    private var isVoiceChatActive: Bool {
        group.voiceChatActive == true
    }
    
    private var participantsInVoiceChat: [GroupMember] {
        group.members.filter { $0.inVoiceChat == true }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Group Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let description = group.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(group.memberCount) Mitglieder")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Voice Chat Status
                HStack(spacing: 8) {
                    Circle()
                        .fill(isVoiceChatActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(isVoiceChatActive ? "Aktiv" : "Inaktiv")
                        .font(.caption)
                        .foregroundColor(isVoiceChatActive ? .green : .gray)
                }
            }
            
            // Participants in Voice Chat
            if isVoiceChatActive && !participantsInVoiceChat.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Im Voice Chat:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        ForEach(participantsInVoiceChat.prefix(3)) { member in
                            AsyncImage(url: URL(string: member.profilePictureUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray)
                                    .overlay(
                                        Text(String(member.displayName.prefix(1)))
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                        }
                        
                        if participantsInVoiceChat.count > 3 {
                            Text("+\(participantsInVoiceChat.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // Action Button
            Button(action: isVoiceChatActive ? onLeave : onJoin) {
                HStack {
                    Image(systemName: isVoiceChatActive ? "phone.down.fill" : "phone.fill")
                    Text(isVoiceChatActive ? "Verlassen" : "Beitreten")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isVoiceChatActive ? Color.red : Color.blue)
                )
                .foregroundColor(.white)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct EmptyGroupsView: View {
    let onCreateGroup: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Keine Gruppen vorhanden")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Erstelle eine neue Gruppe, um mit deinen Freunden zu chatten")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: onCreateGroup) {
                HStack {
                    Image(systemName: "plus")
                    Text("Gruppe erstellen")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(40)
    }
}

#Preview {
    VoiceChatView()
}
