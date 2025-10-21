//
//  GroupManager.swift
//  WalkiCar - Server-basierte Audio-Übertragung
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
    private let serverAudioEngine = ServerAudioEngine.shared
    
    // Rate Limiting für API-Aufrufe
    private var lastVoiceChatStatusLoad: [Int: Date] = [:]
    private let voiceChatStatusLoadInterval: TimeInterval = 2.0 // Mindestens 2 Sekunden zwischen Aufrufen
    
    var activeGroupsCount: Int {
        groups.filter { $0.isActive }.count
    }
    
    var groupsWithActiveVoiceChat: [Group] {
        groups.filter { $0.voiceChatActive == true }
    }
    
    init() {
        setupWebSocketListeners()
        
        // WebSocket-Verbindung herstellen
        webSocketManager.connect()
        
        // Benutzer-Raum beitreten wenn eingeloggt
        if let userId = AuthManager.shared.currentUser?.id {
            webSocketManager.joinUserRoom(userId: userId)
        }
    }
    
    // MARK: - Public Methods
    
    func loadGroups() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let groups = try await apiClient.getGroups()
                
                await MainActor.run {
                    self.groups = groups
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
    
    func createGroup(name: String, description: String) {
        Task {
            do {
                let response = try await apiClient.createGroup(name: name, description: description)
                
                await MainActor.run {
                    if response.success {
                        self.loadGroups() // Gruppen neu laden
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
    
    func joinGroup(groupId: Int) {
        Task {
            do {
                let response = try await apiClient.joinGroup(groupId: groupId)
                
                await MainActor.run {
                    if response.success {
                        self.loadGroups() // Gruppen neu laden
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
                        self.loadGroups() // Gruppen neu laden
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
    
    // MARK: - Voice Chat Methods (Server-basierte Audio-Übertragung)
    
    func joinVoiceChat(group: Group) {
        joinVoiceChat(groupId: group.id)
    }
    
    func joinVoiceChat(groupId: Int) {
        Task {
            do {
                let response = try await apiClient.joinGroupVoiceChat(groupId: groupId)
                
                await MainActor.run {
                    if response.success {
                        // Voice Chat Status aktualisieren
                        self.updateGroupVoiceChatStatus(groupId: groupId, isActive: true)
                        
                        // WebSocket Rooms beitreten
                        if let userId = AuthManager.shared.currentUser?.id {
                            // Benutzer-Raum beitreten
                            self.webSocketManager.joinUserRoom(userId: userId)
                            
                            // Gruppen-Raum beitreten
                            self.webSocketManager.joinGroupRoom(userId: userId, groupId: groupId)
                            
                            // Voice Chat beitreten
                            self.webSocketManager.joinGroupVoiceChat(userId: userId, groupId: groupId)
                            
                            // Server-basierte Audio-Übertragung starten
                            self.serverAudioEngine.startVoiceChat(groupId: groupId, userId: userId)
                        } else {
                            print("❌ GroupManager: Keine User-ID verfügbar für WebSocket-Räume")
                            print("🔍 GroupManager: Versuche User-ID aus Token zu extrahieren...")
                            
                            // Fallback: User-ID aus Token extrahieren
                            if let token = APIClient.shared.getAuthToken() {
                                let parts = token.split(separator: ".")
                                if parts.count >= 2 {
                                    let payload = String(parts[1])
                                    if let data = Data(base64Encoded: payload + "==") {
                                        do {
                                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                               let userId = json["userId"] as? Int {
                                                print("👤 GroupManager: User-ID aus Token extrahiert: \(userId)")
                                                
                                                // Benutzer-Raum beitreten
                                                self.webSocketManager.joinUserRoom(userId: userId)
                                                
                                                // Gruppen-Raum beitreten
                                                self.webSocketManager.joinGroupRoom(userId: userId, groupId: groupId)
                                                
                                                // Voice Chat beitreten
                                                self.webSocketManager.joinGroupVoiceChat(userId: userId, groupId: groupId)
                                                
                                                // Server-basierte Audio-Übertragung starten
                                                self.serverAudioEngine.startVoiceChat(groupId: groupId, userId: userId)
                                            }
                                        } catch {
                                            print("❌ GroupManager: Fehler beim Dekodieren des Tokens: \(error)")
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Aktuelle Gruppe setzen
                        self.currentVoiceChatGroup = self.groups.first { $0.id == groupId }
                        self.isInVoiceChat = true
                        
                        // Server-basierte Audio-Übertragung ist bereits gestartet
                        self.isAudioConnected = true
                        
                        // Voice Chat Status laden
                        self.loadVoiceChatStatus(groupId: groupId)
                        
                        // Audio Level wird von ServerAudioEngine verwaltet
                        // Keine zusätzlichen Teilnehmer-Verbindungen nötig (Server-basiert)
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
    
    func leaveVoiceChat(group: Group) {
        leaveVoiceChat(groupId: group.id)
    }
    
    func leaveVoiceChat(groupId: Int) {
        Task {
            do {
                let response = try await apiClient.leaveGroupVoiceChat(groupId: groupId)
                
                await MainActor.run {
                    if response.success {
                        // Voice Chat Status aktualisieren
                        self.updateGroupVoiceChatStatus(groupId: groupId, isActive: false)
                        
                        // Server-basierte Audio-Übertragung stoppen
                        self.serverAudioEngine.stopVoiceChat()
                        
                        // WebSocket Room verlassen - mit Verzögerung damit Leave-Events empfangen werden
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let userId = AuthManager.shared.currentUser?.id {
                                self.webSocketManager.leaveGroupVoiceChat(userId: userId, groupId: groupId)
                            } else {
                                // Fallback: User-ID aus Token extrahieren
                                if let token = APIClient.shared.getAuthToken() {
                                    let parts = token.split(separator: ".")
                                    if parts.count >= 2 {
                                        let payload = String(parts[1])
                                        if let data = Data(base64Encoded: payload + "==") {
                                            do {
                                                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                                   let userId = json["userId"] as? Int {
                                                    self.webSocketManager.leaveGroupVoiceChat(userId: userId, groupId: groupId)
                                                }
                                            } catch {
                                                print("❌ GroupManager: Fehler beim Dekodieren des Tokens für Leave: \(error)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
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
        // Rate Limiting: Prüfe ob letzter Aufruf zu kurz her ist
        if let lastLoad = lastVoiceChatStatusLoad[groupId] {
            let timeSinceLastLoad = Date().timeIntervalSince(lastLoad)
            if timeSinceLastLoad < voiceChatStatusLoadInterval {
                print("⚠️ GroupManager: Rate Limiting - Voice Chat Status für Gruppe \(groupId) wurde vor \(timeSinceLastLoad)s geladen, überspringe")
                return
            }
        }
        
        // Aktualisiere Zeitstempel
        lastVoiceChatStatusLoad[groupId] = Date()
        
        print("🌐 GroupManager: Lade Voice Chat Status für Gruppe \(groupId)")
        
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
                            createdAt: currentGroup.createdAt,
                            memberCount: currentGroup.memberCount,
                            isActive: currentGroup.isActive,
                            voiceChatActive: status.isActive,
                            voiceChatParticipants: status.participants
                        )
                    }
                }
            } catch {
                print("❌ GroupManager: Fehler beim Laden des Voice Chat Status: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateGroupVoiceChatStatus(groupId: Int, isActive: Bool) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            let currentGroup = groups[index]
            groups[index] = Group(
                id: currentGroup.id,
                name: currentGroup.name,
                description: currentGroup.description,
                creatorId: currentGroup.creatorId,
                createdAt: currentGroup.createdAt,
                memberCount: currentGroup.memberCount,
                isActive: currentGroup.isActive,
                voiceChatActive: isActive,
                voiceChatParticipants: currentGroup.voiceChatParticipants
            )
        }
    }
    
    // MARK: - WebSocket Event Handlers
    
    private func setupWebSocketListeners() {
        // User Joined Voice Chat
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
        
        // User Left Voice Chat
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
        
        // Voice Chat Started
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
        
        // Voice Chat Ended
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
        print("👥 GroupManager: Benutzer \(userId) ist Voice Chat beigetreten für Gruppe \(groupId)")
        
        // Server-basierte Audio-Übertragung - keine WebRTC-Verbindungen nötig
        // Aktualisiere Voice Chat Status für die Gruppe (mit Rate Limiting)
        loadVoiceChatStatus(groupId: groupId)
    }
    
    private func handleUserLeftVoiceChat(groupId: Int, userId: Int) {
        print("👥 GroupManager: Benutzer \(userId) hat Voice Chat verlassen für Gruppe \(groupId)")
        // Entferne Benutzer aus Voice Chat Teilnehmern
        voiceChatParticipants.removeAll { $0.userId == userId }
        
        // Aktualisiere Gruppen-Status (mit Rate Limiting)
        loadVoiceChatStatus(groupId: groupId)
    }
    
    private func handleVoiceChatStarted(groupId: Int) {
        print("🎤 GroupManager: Voice Chat gestartet für Gruppe \(groupId)")
        updateGroupVoiceChatStatus(groupId: groupId, isActive: true)
    }
    
    private func handleVoiceChatEnded(groupId: Int) {
        print("🎤 GroupManager: Voice Chat beendet für Gruppe \(groupId)")
        updateGroupVoiceChatStatus(groupId: groupId, isActive: false)
        
        // Wenn wir in diesem Voice Chat waren, verlassen wir ihn auch
        if isInVoiceChat && currentVoiceChatGroup?.id == groupId {
            currentVoiceChatGroup = nil
            voiceChatParticipants = []
            isInVoiceChat = false
            isAudioConnected = false
            audioLevel = 0.0
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}