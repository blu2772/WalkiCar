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
