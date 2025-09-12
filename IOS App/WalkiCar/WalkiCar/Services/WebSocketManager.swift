import Foundation
import SocketIO 

class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectionError: String?
    
    // MARK: - Private Properties
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private let apiClient = APIClient.shared
    
    // MARK: - Initialization
    private init() {
        setupSocket()
    }
    
    private func setupSocket() {
        guard let url = URL(string: "https://walkcar.timrmp.de") else {
            print("❌ WebSocketManager: Ungültige URL")
            return
        }
        
        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectAttempts(5),
            .reconnectWait(1000)
        ])
        
        socket = manager?.defaultSocket
        
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        guard let socket = socket else { return }
        
        // Connection events
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            print("🔌 WebSocketManager: Verbunden")
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.connectionError = nil
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("🔌 WebSocketManager: Getrennt")
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        socket.on(clientEvent: .error) { [weak self] data, ack in
            print("❌ WebSocketManager: Verbindungsfehler")
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.connectionError = "Verbindungsfehler"
            }
        }
        
        // Location tracking events
        socket.on("friend_went_live") { [weak self] data, ack in
            print("📍 WebSocketManager: Freund ist live gegangen")
            DispatchQueue.main.async {
                // Benachrichtige LocationManager über Live-Update
                NotificationCenter.default.post(
                    name: NSNotification.Name("FriendWentLive"),
                    object: data.first
                )
            }
        }
        
        socket.on("friend_parked") { [weak self] data, ack in
            print("🅿️ WebSocketManager: Freund hat geparkt")
            DispatchQueue.main.async {
                // Benachrichtige LocationManager über Park-Update
                NotificationCenter.default.post(
                    name: NSNotification.Name("FriendParked"),
                    object: data.first
                )
            }
        }
        
        socket.on("friend_location_update") { [weak self] data, ack in
            print("📍 WebSocketManager: Freund-Standort aktualisiert")
            DispatchQueue.main.async {
                // Benachrichtige LocationManager über Standort-Update
                NotificationCenter.default.post(
                    name: NSNotification.Name("FriendLocationUpdate"),
                    object: data.first
                )
            }
        }
        
        socket.on("location_tracking_error") { [weak self] data, ack in
            print("❌ WebSocketManager: Standort-Tracking-Fehler")
            DispatchQueue.main.async {
                self?.connectionError = "Standort-Tracking-Fehler"
            }
        }
        
        // Voice Chat Events
        socket.on("user_joined_voice_chat") { [weak self] data, ack in
            print("🎤 WebSocketManager: Benutzer ist Voice Chat beigetreten")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserJoinedVoiceChat"),
                    object: data.first
                )
            }
        }
        
        socket.on("user_left_voice_chat") { [weak self] data, ack in
            print("🎤 WebSocketManager: Benutzer hat Voice Chat verlassen")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserLeftVoiceChat"),
                    object: data.first
                )
            }
        }
        
        socket.on("voice_chat_started") { [weak self] data, ack in
            print("🎤 WebSocketManager: Voice Chat gestartet")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("VoiceChatStarted"),
                    object: data.first
                )
            }
        }
        
        socket.on("voice_chat_ended") { [weak self] data, ack in
            print("🎤 WebSocketManager: Voice Chat beendet")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("VoiceChatEnded"),
                    object: data.first
                )
            }
        }
        
        socket.on("voice_chat_error") { [weak self] data, ack in
            print("❌ WebSocketManager: Voice Chat Fehler")
            DispatchQueue.main.async {
                self?.connectionError = "Voice Chat Fehler"
            }
        }
        
        // WebRTC Signaling Events
        socket.on("webrtc_offer") { [weak self] data, ack in
            print("🎤 WebSocketManager: WebRTC Offer erhalten")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WebRTCOffer"),
                    object: data.first
                )
            }
        }
        
        socket.on("webrtc_answer") { [weak self] data, ack in
            print("🎤 WebSocketManager: WebRTC Answer erhalten")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WebRTCAnswer"),
                    object: data.first
                )
            }
        }
        
        socket.on("webrtc_ice_candidate") { [weak self] data, ack in
            print("🎤 WebSocketManager: WebRTC ICE Candidate erhalten")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WebRTCIceCandidate"),
                    object: data.first
                )
            }
        }
        
        socket.on("webrtc_end_call") { [weak self] data, ack in
            print("🎤 WebSocketManager: WebRTC End Call erhalten")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("WebRTCEndCall"),
                    object: data.first
                )
            }
        }
    }
    
    // MARK: - Public Methods
    
    func connect() {
        guard let socket = socket else {
            print("❌ WebSocketManager: Socket nicht verfügbar")
            return
        }
        
        print("🔌 WebSocketManager: Verbinde...")
        socket.connect()
    }
    
    func disconnect() {
        guard let socket = socket else { return }
        
        print("🔌 WebSocketManager: Trenne Verbindung...")
        socket.disconnect()
    }
    
    func startLocationTracking(userId: Int, carId: Int?) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "userId": userId,
            "carId": carId as Any
        ]
        
        socket.emit("start_location_tracking", data)
        print("📍 WebSocketManager: Standort-Tracking gestartet für User \(userId)")
    }
    
    func stopLocationTracking(userId: Int, carId: Int?) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "userId": userId,
            "carId": carId as Any
        ]
        
        socket.emit("stop_location_tracking", data)
        print("🅿️ WebSocketManager: Standort-Tracking gestoppt für User \(userId)")
    }
    
    func sendLocationUpdate(userId: Int, carId: Int?, latitude: Double, longitude: Double, accuracy: Float?, speed: Float?, heading: Float?, altitude: Float?, bluetoothConnected: Bool) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        var data: [String: Any] = [
            "userId": userId,
            "carId": carId as Any,
            "latitude": latitude,
            "longitude": longitude,
            "bluetoothConnected": bluetoothConnected
        ]
        
        if let accuracy = accuracy { data["accuracy"] = accuracy }
        if let speed = speed { data["speed"] = speed }
        if let heading = heading { data["heading"] = heading }
        if let altitude = altitude { data["altitude"] = altitude }
        
        socket.emit("location_update", data)
    }
    
    func joinFriendsRoom(userId: Int) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "userId": userId
        ]
        
        socket.emit("join_friends_room", data)
        print("👥 WebSocketManager: Freunde-Raum beigetreten für User \(userId)")
    }
    
    // MARK: - Voice Chat Methods
    
    func joinGroupVoiceChat(userId: Int, groupId: Int) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "userId": userId,
            "groupId": groupId
        ]
        
        socket.emit("join_group_voice_chat", data)
        print("🎤 WebSocketManager: Voice Chat beigetreten für Gruppe \(groupId)")
    }
    
    func leaveGroupVoiceChat(userId: Int, groupId: Int) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "userId": userId,
            "groupId": groupId
        ]
        
        socket.emit("leave_group_voice_chat", data)
        print("🎤 WebSocketManager: Voice Chat verlassen für Gruppe \(groupId)")
    }
    
    func joinGroupRoom(userId: Int, groupId: Int) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "userId": userId,
            "groupId": groupId
        ]
        
        socket.emit("join_group_room", data)
        print("👥 WebSocketManager: Gruppen-Raum beigetreten für Gruppe \(groupId)")
    }
    
    func joinUserRoom(userId: Int) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "userId": userId
        ]
        
        socket.emit("join_user_room", data)
        print("👤 WebSocketManager: Benutzer-Raum beigetreten für User \(userId)")
    }
    
    // MARK: - WebRTC Signaling Methods
    
    func sendWebRTCOffer(fromUserId: Int, targetUserId: Int, groupId: Int, offer: [String: Any]) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "fromUserId": fromUserId,
            "targetUserId": targetUserId,
            "groupId": groupId,
            "offer": offer
        ]
        
        socket.emit("webrtc_offer", data)
        print("🎤 WebSocketManager: WebRTC Offer gesendet an User \(targetUserId)")
    }
    
    func sendWebRTCAnswer(fromUserId: Int, targetUserId: Int, groupId: Int, answer: [String: Any]) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "fromUserId": fromUserId,
            "targetUserId": targetUserId,
            "groupId": groupId,
            "answer": answer
        ]
        
        socket.emit("webrtc_answer", data)
        print("🎤 WebSocketManager: WebRTC Answer gesendet an User \(targetUserId)")
    }
    
    func sendWebRTCIceCandidate(fromUserId: Int, targetUserId: Int, groupId: Int, candidate: [String: Any]) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "fromUserId": fromUserId,
            "targetUserId": targetUserId,
            "groupId": groupId,
            "candidate": candidate
        ]
        
        socket.emit("webrtc_ice_candidate", data)
        print("🎤 WebSocketManager: WebRTC ICE Candidate gesendet an User \(targetUserId)")
    }
    
    func sendWebRTCEndCall(fromUserId: Int, targetUserId: Int, groupId: Int) {
        guard let socket = socket, isConnected else {
            print("❌ WebSocketManager: Socket nicht verbunden")
            return
        }
        
        let data: [String: Any] = [
            "fromUserId": fromUserId,
            "targetUserId": targetUserId,
            "groupId": groupId
        ]
        
        socket.emit("webrtc_end_call", data)
        print("🎤 WebSocketManager: WebRTC End Call gesendet an User \(targetUserId)")
    }
    
    // MARK: - Helper Methods
    
    func reconnect() {
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connect()
        }
    }
    
    func isSocketConnected() -> Bool {
        return socket?.status == .connected
    }
}
