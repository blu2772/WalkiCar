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
        
        // WebSocket-Verbindung herstellen
        webSocketManager.connect()
        
        // Benutzer-Raum beitreten wenn eingeloggt
        if let userId = AuthManager.shared.currentUser?.id {
            webSocketManager.joinUserRoom(userId: userId)
        }
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
                        
                        // WebSocket Rooms beitreten
                        if let userId = AuthManager.shared.currentUser?.id {
                            print("🎤 GroupManager: Trete WebSocket-Räumen bei für User \(userId), Gruppe \(groupId)")
                            
                            // Benutzer-Raum beitreten (falls noch nicht geschehen)
                            self.webSocketManager.joinUserRoom(userId: userId)
                            
                            // Gruppen-Raum beitreten
                            self.webSocketManager.joinGroupRoom(userId: userId, groupId: groupId)
                            
                            // Voice Chat beitreten
                            self.webSocketManager.joinGroupVoiceChat(userId: userId, groupId: groupId)
                            
                            // WebRTC Voice Chat starten
                            self.webRTCPeerManager.startVoiceChat(groupId: groupId, userId: userId)
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
                                                
                                                // WebRTC Voice Chat starten
                                                self.webRTCPeerManager.startVoiceChat(groupId: groupId, userId: userId)
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
                        
                        // Audio Engine starten
                        self.audioEngine.startAudio()
                        self.isAudioConnected = true
                        
                        // Voice Chat Status laden
                        self.loadVoiceChatStatus(groupId: groupId)
                        
                        // Audio Level Monitoring starten
                        self.startAudioLevelMonitoring()
                        
                        // Nach kurzer Verzögerung: Prüfe auf bereits vorhandene Teilnehmer
                        // Warte bis User-Profil geladen ist oder verwende Token-Fallback
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.connectToExistingParticipants(groupId: groupId)
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
    
    func leaveVoiceChat(groupId: Int) {
        Task {
            do {
                let response = try await apiClient.leaveGroupVoiceChat(groupId: groupId)
                
                await MainActor.run {
                    if response.success {
                        // Voice Chat Status aktualisieren
                        self.updateGroupVoiceChatStatus(groupId: groupId, isActive: false)
                        
                        // WebRTC Voice Chat stoppen
                        self.webRTCPeerManager.stopVoiceChat()
                        
                        // Audio Engine stoppen
                        self.audioEngine.stopAudio()
                        
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
            print("🔔 GroupManager: UserJoinedVoiceChat Notification empfangen - Object: \(notification.object ?? "nil")")
            guard let data = notification.object as? [String: Any],
                  let groupId = data["groupId"] as? Int,
                  let userId = data["userId"] as? Int else { 
                print("❌ GroupManager: UserJoinedVoiceChat - Ungültige Daten: \(notification.object ?? "nil")")
                return 
            }
            
            Task { @MainActor in
                self?.handleUserJoinedVoiceChat(groupId: groupId, userId: userId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserLeftVoiceChat"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🔔 GroupManager: UserLeftVoiceChat Notification empfangen - Object: \(notification.object ?? "nil")")
            guard let data = notification.object as? [String: Any],
                  let groupId = data["groupId"] as? Int,
                  let userId = data["userId"] as? Int else { 
                print("❌ GroupManager: UserLeftVoiceChat - Ungültige Daten: \(notification.object ?? "nil")")
                return 
            }
            
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
        print("👥 GroupManager: Benutzer \(userId) ist Voice Chat beigetreten für Gruppe \(groupId)")
        
        // Prüfe ob wir selbst im Voice Chat sind
        if isInVoiceChat && currentVoiceChatGroup?.id == groupId {
            // Füge neuen Teilnehmer zur WebRTC Verbindung hinzu
            print("🎤 GroupManager: Füge neuen Teilnehmer \(userId) zur WebRTC Verbindung hinzu")
            webRTCPeerManager.addParticipant(userId: userId)
        } else {
            print("🎤 GroupManager: Wir sind nicht im Voice Chat oder es ist nicht unsere Gruppe")
            print("🎤 GroupManager: isInVoiceChat: \(isInVoiceChat), currentGroup: \(currentVoiceChatGroup?.id ?? -1), targetGroup: \(groupId)")
        }
        
        // Aktualisiere Voice Chat Status für die Gruppe
        loadVoiceChatStatus(groupId: groupId)
    }
    
    private func handleUserLeftVoiceChat(groupId: Int, userId: Int) {
        print("👥 GroupManager: Benutzer \(userId) hat Voice Chat verlassen für Gruppe \(groupId)")
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
    
    private func connectToExistingParticipants(groupId: Int) {
        print("🎤 GroupManager: Verbinde mit bereits vorhandenen Teilnehmern für Gruppe \(groupId)")
        
        // Debug: Prüfe AuthManager Status
        print("🔍 GroupManager: AuthManager Status:")
        print("   - isAuthenticated: \(AuthManager.shared.isAuthenticated)")
        print("   - currentUser: \(AuthManager.shared.currentUser?.username ?? "nil")")
        print("   - currentUser ID: \(AuthManager.shared.currentUser?.id ?? -1)")
        
        // Debug: Prüfe Token
        if let token = APIClient.shared.getAuthToken() {
            print("🔍 GroupManager: Auth Token verfügbar: \(String(token.prefix(20)))...")
        } else {
            print("❌ GroupManager: Kein Auth Token verfügbar!")
        }
        
        // Lade Voice Chat Status um andere Teilnehmer zu finden
        Task {
            do {
                let status = try await apiClient.getGroupVoiceChatStatus(groupId: groupId)
                print("🔍 GroupManager: Voice Chat Status geladen - \(status.participants.count) Teilnehmer")
                
                await MainActor.run {
                    // Erstelle Peer Connections für alle anderen Teilnehmer
                    for participant in status.participants {
                        print("🔍 GroupManager: Prüfe Teilnehmer \(participant.userId) (\(participant.username))")
                        
                        // Versuche User-ID aus AuthManager zu bekommen, falls nicht verfügbar aus Token extrahieren
                        var currentUserId: Int?
                        
                        if let userId = AuthManager.shared.currentUser?.id {
                            currentUserId = userId
                            print("✅ GroupManager: User-ID aus AuthManager: \(userId)")
                        } else {
                            print("⚠️ GroupManager: currentUser ist nil, verwende Token-Fallback")
                            // Fallback: User-ID aus Token extrahieren
                            if let token = APIClient.shared.getAuthToken() {
                                do {
                                    let payload = try decodeJWT(token: token)
                                    if let userId = payload["userId"] as? Int {
                                        currentUserId = userId
                                        print("✅ GroupManager: User-ID aus Token extrahiert für Peer Connections: \(userId)")
                                    }
                                } catch {
                                    print("❌ GroupManager: Fehler beim Dekodieren des Tokens für Peer Connections: \(error)")
                                }
                            }
                        }
                        
                        if let currentUserId = currentUserId,
                           participant.userId != currentUserId {
                            print("🎤 GroupManager: Erstelle Peer Connection für bereits vorhandenen Teilnehmer \(participant.userId)")
                            webRTCPeerManager.addParticipant(userId: participant.userId)
                        } else if let currentUserId = currentUserId {
                            print("ℹ️ GroupManager: Überspringe eigenen User \(currentUserId)")
                        } else {
                            print("❌ GroupManager: Keine User-ID verfügbar - kann keine Peer Connections erstellen")
                        }
                    }
                }
            } catch {
                print("❌ GroupManager: Fehler beim Laden der Teilnehmer für Peer Connections: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func decodeJWT(token: String) throws -> [String: Any] {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw NSError(domain: "JWTError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JWT format"])
        }
        
        let payload = parts[1]
        
        // Base64 URL decode
        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "JWTError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JWT payload"])
        }
        
        return json
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
