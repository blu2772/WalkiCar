//
//  GroupManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import AVFoundation

@MainActor
class GroupManager: ObservableObject {
    @Published var groups: [Group] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentVoiceChatGroup: Group?
    @Published var voiceChatParticipants: [VoiceChatParticipant] = []
    @Published var isInVoiceChat = false
    @Published var isAudioConnected = false
    @Published var audioLevel: Float = 0.0
    
    private let apiClient = APIClient.shared
    private let webSocketManager = WebSocketManager.shared
    private let webRTCPeerManager = WebRTCPeerConnectionManager.shared
    private let audioEngine = WebRTCAudioEngine.shared
    
    var activeGroupsCount: Int {
        groups.filter { $0.isActive }.count
    }
    
    var groupsWithActiveVoiceChat: [Group] {
        groups.filter { $0.voiceChatActive == true }
    }
    
    init() {
        setupWebSocketListeners()
    }
    
    // MARK: - Group Management
    
    func loadGroups() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.getGroupsList()
                await MainActor.run {
                    self.groups = response.groups
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func createGroup(name: String, description: String?, friendIds: [Int]) {
        Task {
            do {
                let request = CreateGroupRequest(
                    name: name,
                    description: description,
                    friendIds: friendIds
                )
                let response = try await apiClient.createGroup(request)
                
                await MainActor.run {
                    if response.success {
                        // Gruppe erfolgreich erstellt, Liste neu laden
                        self.loadGroups()
                    } else {
                        self.errorMessage = response.message
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func leaveGroup(groupId: Int) {
        Task {
            do {
                let response = try await apiClient.leaveGroup(groupId: groupId)
                
                await MainActor.run {
                    if response.success {
                        // Gruppe verlassen, aus lokaler Liste entfernen
                        self.groups.removeAll { $0.id == groupId }
                        
                        // Falls aktueller Voice Chat verlassen wurde
                        if self.currentVoiceChatGroup?.id == groupId {
                            self.currentVoiceChatGroup = nil
                            self.voiceChatParticipants = []
                            self.isInVoiceChat = false
                        }
                    } else {
                        self.errorMessage = response.message
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Voice Chat Management
    
    func joinVoiceChat(groupId: Int) {
        Task {
            do {
                let response = try await apiClient.joinGroupVoiceChat(groupId: groupId)
                
                await MainActor.run {
                    if response.success {
                        // Voice Chat Status aktualisieren
                        self.updateGroupVoiceChatStatus(groupId: groupId, isActive: true)
                        
                        // WebSocket Room beitreten
                        if let userId = AuthManager.shared.currentUser?.id {
                            self.webSocketManager.joinGroupVoiceChat(userId: userId, groupId: groupId)
                            
                            // WebRTC Voice Chat starten
                            self.webRTCPeerManager.startVoiceChat(groupId: groupId, userId: userId)
                        }
                        
                        // Aktuelle Gruppe setzen
                        self.currentVoiceChatGroup = self.groups.first { $0.id == groupId }
                        self.isInVoiceChat = true
                        
                        // Audio Engine starten
                        self.audioEngine.startAudio()
                        self.isAudioConnected = true
                        
                        // Voice Chat Status laden
                        self.loadVoiceChatStatus(groupId: groupId)
                        
                        // Audio Level Monitoring starten
                        self.startAudioLevelMonitoring()
                    } else {
                        self.errorMessage = response.message
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func leaveVoiceChat(groupId: Int) {
        Task {
            do {
                let response = try await apiClient.leaveGroupVoiceChat(groupId: groupId)
                
                await MainActor.run {
                    if response.success {
                        // Voice Chat Status aktualisieren
                        self.updateGroupVoiceChatStatus(groupId: groupId, isActive: false)
                        
                        // WebSocket Room verlassen
                        if let userId = AuthManager.shared.currentUser?.id {
                            self.webSocketManager.leaveGroupVoiceChat(userId: userId, groupId: groupId)
                            
                            // WebRTC Voice Chat stoppen
                            self.webRTCPeerManager.stopVoiceChat()
                        }
                        
                        // Audio Engine stoppen
                        self.audioEngine.stopAudio()
                        self.isAudioConnected = false
                        self.audioLevel = 0.0
                        
                        // Aktuelle Gruppe zurücksetzen falls es die gleiche ist
                        if self.currentVoiceChatGroup?.id == groupId {
                            self.currentVoiceChatGroup = nil
                            self.voiceChatParticipants = []
                            self.isInVoiceChat = false
                        }
                    } else {
                        self.errorMessage = response.message
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func loadVoiceChatStatus(groupId: Int) {
        Task {
            do {
                let status = try await apiClient.getGroupVoiceChatStatus(groupId: groupId)
                
                await MainActor.run {
                    self.voiceChatParticipants = status.participants
                    
                    // Aktualisiere Gruppen-Status
                    if let index = self.groups.firstIndex(where: { $0.id == groupId }) {
                        let currentGroup = self.groups[index]
                        self.groups[index] = Group(
                            id: currentGroup.id,
                            name: currentGroup.name,
                            description: currentGroup.description,
                            creatorId: currentGroup.creatorId,
                            isPublic: currentGroup.isPublic,
                            maxMembers: currentGroup.maxMembers,
                            isActive: currentGroup.isActive,
                            createdAt: currentGroup.createdAt,
                            updatedAt: currentGroup.updatedAt,
                            memberCount: currentGroup.memberCount,
                            voiceChatActive: status.isActive,
                            voiceChatStartedAt: status.participants.first?.startedAt,
                            members: currentGroup.members
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateGroupVoiceChatStatus(groupId: Int, isActive: Bool) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            let group = groups[index]
            groups[index] = Group(
                id: group.id,
                name: group.name,
                description: group.description,
                creatorId: group.creatorId,
                isPublic: group.isPublic,
                maxMembers: group.maxMembers,
                isActive: group.isActive,
                createdAt: group.createdAt,
                updatedAt: group.updatedAt,
                memberCount: group.memberCount,
                voiceChatActive: isActive,
                voiceChatStartedAt: isActive ? group.voiceChatStartedAt : nil,
                members: group.members
            )
        }
    }
    
    // MARK: - WebSocket Integration
    
    private func setupWebSocketListeners() {
        // Voice Chat Events
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserJoinedVoiceChat"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let groupId = data["groupId"] as? Int,
                  let userId = data["userId"] as? Int else { return }
            
            Task { @MainActor in
                self?.handleUserJoinedVoiceChat(groupId: groupId, userId: userId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserLeftVoiceChat"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let groupId = data["groupId"] as? Int,
                  let userId = data["userId"] as? Int else { return }
            
            Task { @MainActor in
                self?.handleUserLeftVoiceChat(groupId: groupId, userId: userId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VoiceChatStarted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let groupId = data["groupId"] as? Int else { return }
            
            Task { @MainActor in
                self?.handleVoiceChatStarted(groupId: groupId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VoiceChatEnded"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let data = notification.object as? [String: Any],
                  let groupId = data["groupId"] as? Int else { return }
            
            Task { @MainActor in
                self?.handleVoiceChatEnded(groupId: groupId)
            }
        }
    }
    
    private func handleUserJoinedVoiceChat(groupId: Int, userId: Int) {
        // Aktualisiere Voice Chat Status für die Gruppe
        loadVoiceChatStatus(groupId: groupId)
    }
    
    private func handleUserLeftVoiceChat(groupId: Int, userId: Int) {
        // Entferne Benutzer aus Voice Chat Teilnehmern
        voiceChatParticipants.removeAll { $0.userId == userId }
        
        // Aktualisiere Gruppen-Status
        loadVoiceChatStatus(groupId: groupId)
    }
    
    private func handleVoiceChatStarted(groupId: Int) {
        // Aktualisiere Gruppen-Status
        updateGroupVoiceChatStatus(groupId: groupId, isActive: true)
    }
    
    private func handleVoiceChatEnded(groupId: Int) {
        // Aktualisiere Gruppen-Status
        updateGroupVoiceChatStatus(groupId: groupId, isActive: false)
        
        // Falls es die aktuelle Gruppe ist, Voice Chat beenden
        if currentVoiceChatGroup?.id == groupId {
            currentVoiceChatGroup = nil
            voiceChatParticipants = []
            isInVoiceChat = false
            isAudioConnected = false
            audioLevel = 0.0
        }
    }
    
    // MARK: - Audio Controls
    
    func toggleMicrophone() {
        audioEngine.toggleMicrophone()
    }
    
    func toggleSpeaker() {
        audioEngine.toggleSpeaker()
    }
    
    func setSpeakerMode(_ mode: AVAudioSession.PortOverride) {
        audioEngine.setSpeakerMode(mode)
    }
    
    private func startAudioLevelMonitoring() {
        // Audio Level wird automatisch vom WebRTCAudioEngine aktualisiert
        // Hier könnten wir zusätzliche Monitoring-Logik hinzufügen
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
