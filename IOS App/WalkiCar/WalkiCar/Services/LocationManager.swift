import Foundation
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var liveLocations: [Location] = []
    @Published var parkedLocations: [ParkedLocation] = []
    @Published var isTracking = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let apiClient = APIClient.shared
    // private let webSocketManager = WebSocketManager.shared // Temporär deaktiviert
    private var updateTimer: Timer?
    private var lastUpdateTime: Date?
    private let updateInterval: TimeInterval = 5.0 // 5 Sekunden
    private var currentUserId: Int?
    private var activeCarId: Int?
    private var isAppInForeground = true
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        setupWebSocketNotifications()
        setupAppLifecycleNotifications()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Mindestens 10 Meter Bewegung
        authorizationStatus = locationManager.authorizationStatus
        isLocationEnabled = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    private func setupAppLifecycleNotifications() {
        // App-Lifecycle-Überwachung für automatisches Standort-Tracking
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        print("📍 LocationManager: App-Lifecycle-Überwachung gestartet")
    }
    
    private func setupWebSocketNotifications() {
        // WebSocket-Benachrichtigungen für Real-time Updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFriendWentLive),
            name: NSNotification.Name("FriendWentLive"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFriendParked),
            name: NSNotification.Name("FriendParked"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFriendLocationUpdate),
            name: NSNotification.Name("FriendLocationUpdate"),
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationTracking() {
        guard isLocationEnabled else {
            errorMessage = "Standortzugriff ist nicht aktiviert"
            return
        }
        
        locationManager.startUpdatingLocation()
        isTracking = true
        
        // Timer für regelmäßige Updates starten
        startUpdateTimer()
        
        // WebSocket-Verbindung starten (temporär deaktiviert)
        // webSocketManager.connect()
        
        // Freunde-Raum beitreten (temporär deaktiviert)
        // if let userId = currentUserId {
        //     webSocketManager.joinFriendsRoom(userId: userId)
        //     webSocketManager.startLocationTracking(userId: userId, carId: nil)
        // }
        
        print("📍 LocationManager: Standort-Tracking gestartet")
    }
    
    func stopLocationTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
        
        // Timer stoppen
        stopUpdateTimer()
        
        print("📍 LocationManager: Standort-Tracking gestoppt")
    }
    
    func setActiveCar(carId: Int?) {
        activeCarId = carId
        print("📍 LocationManager: Aktives Auto gesetzt - ID: \(carId ?? -1)")
        
        // Starte automatisch Standort-Tracking wenn Auto gesetzt wird
        if carId != nil {
            checkAndStartAutomaticTracking()
        }
    }
    
    // MARK: - App Lifecycle Handlers
    
    @objc private func appDidBecomeActive() {
        isAppInForeground = true
        print("📍 LocationManager: App wurde aktiv - prüfe automatisches Tracking")
        checkAndStartAutomaticTracking()
    }
    
    @objc private func appWillResignActive() {
        print("📍 LocationManager: App wird inaktiv")
    }
    
    @objc private func appDidEnterBackground() {
        isAppInForeground = false
        print("📍 LocationManager: App im Hintergrund - Tracking läuft weiter")
    }
    
    @objc private func appWillEnterForeground() {
        isAppInForeground = true
        print("📍 LocationManager: App kommt in Vordergrund - prüfe Tracking")
        checkAndStartAutomaticTracking()
    }
    
    // MARK: - Automatic Tracking
    
    private func checkAndStartAutomaticTracking() {
        // Delegiere an AppStateManager für komplexe Logik
        Task { @MainActor in
            AppStateManager.shared.checkAndStartAutomaticTracking()
        }
    }
    
    func updateLocationToServer(carId: Int?, bluetoothConnected: Bool = false) {
        guard let location = currentLocation else {
            print("📍 LocationManager: Kein aktueller Standort verfügbar")
            return
        }

        // Verwende das aktive Auto, falls keine carId übergeben wurde
        let carIdToUse = carId ?? activeCarId

        // Nur Standort-Updates senden, wenn ein Auto aktiv ist
        guard carIdToUse != nil else {
            print("📍 LocationManager: Kein aktives Auto - kein Standort-Update")
            return
        }

        let request = LocationUpdateRequest(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: Float(location.horizontalAccuracy),
            speed: location.speed >= 0 ? Float(location.speed) : nil,
            heading: location.course >= 0 ? Float(location.course) : nil,
            altitude: Float(location.altitude),
            carId: carIdToUse,
            bluetoothConnected: bluetoothConnected
        )
        
        Task {
            do {
                let response = try await apiClient.updateLocation(request)
                print("📍 LocationManager: Standort erfolgreich aktualisiert - ID: \(response.locationId)")
                lastUpdateTime = Date()
            } catch {
                print("❌ LocationManager: Standort-Update fehlgeschlagen: \(error)")
                await MainActor.run {
                    errorMessage = "Standort konnte nicht aktualisiert werden: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func parkCar(carId: Int) {
        let request = ParkCarRequest(carId: carId)
        
        Task {
            do {
                try await apiClient.parkCar(request)
                print("🅿️ LocationManager: Fahrzeug \(carId) als geparkt markiert")
            } catch {
                print("❌ LocationManager: Parken fehlgeschlagen: \(error)")
                await MainActor.run {
                    errorMessage = "Fahrzeug konnte nicht als geparkt markiert werden: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func fetchLiveLocations() {
        Task {
            do {
                let response = try await apiClient.getLiveLocations()
                await MainActor.run {
                    self.liveLocations = response.liveLocations
                    self.parkedLocations = response.parkedLocations
                }
                print("📍 LocationManager: Live-Standorte aktualisiert - \(response.liveLocations.count) live, \(response.parkedLocations.count) geparkt")
            } catch {
                print("❌ LocationManager: Live-Standorte konnten nicht abgerufen werden: \(error)")
                await MainActor.run {
                    errorMessage = "Live-Standorte konnten nicht abgerufen werden: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func fetchLocationHistory(carId: Int, days: Int = 7) async throws -> LocationHistoryResponse {
        return try await apiClient.getLocationHistory(carId: carId, days: days)
    }
    
    func updateLocationSettings(_ settings: LocationSettingsRequest) async throws {
        try await apiClient.updateLocationSettings(settings)
    }
    
    func fetchLocationSettings() async throws -> LocationSettingsResponse {
        return try await apiClient.getLocationSettings()
    }
    
    // MARK: - Private Methods
    
    private func startUpdateTimer() {
        stopUpdateTimer() // Sicherstellen, dass kein Timer läuft
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.performPeriodicUpdate()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func performPeriodicUpdate() {
        guard isTracking, let _ = currentLocation else { return }
        
        // Prüfe ob genug Zeit vergangen ist seit dem letzten Update
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < updateInterval {
            return
        }
        
        // Update an Server senden (ohne spezifisches Auto)
        updateLocationToServer(carId: nil, bluetoothConnected: false)
        
        // Live-Standorte von Freunden aktualisieren
        fetchLiveLocations()
    }
    
    // MARK: - Helper Methods
    
    func getLocationStatus(for location: Location) -> LocationStatus {
        if let isLive = location.isLive, let bluetoothConnected = location.bluetoothConnected, isLive && bluetoothConnected {
            return .live
        } else if let isParked = location.isParked, isParked {
            return .parked
        } else {
            return .offline
        }
    }
    
    func getLocationStatus(for parkedLocation: ParkedLocation) -> LocationStatus {
        // Prüfe ob der letzte Live-Update noch "frisch" ist (innerhalb der letzten Stunde)
        if let lastUpdate = parkedLocation.lastLiveUpdate,
           let updateDate = ISO8601DateFormatter().date(from: lastUpdate),
           Date().timeIntervalSince(updateDate) < 3600 { // 1 Stunde
            return .parked
        } else {
            return .offline
        }
    }
    
    func formatDistance(from location: CLLocation) -> String {
        guard let current = currentLocation else { return "Unbekannt" }
        
        let distance = current.distance(from: location)
        
        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    func formatLastUpdate(_ timestamp: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: timestamp) else {
            return "Unbekannt"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - WebSocket Handlers
    
    @objc private func handleFriendWentLive(_ notification: Notification) {
        guard let data = notification.object as? [String: Any] else { return }
        
        print("📍 LocationManager: Freund ist live gegangen: \(data)")
        
        // Aktualisiere Live-Standorte
        fetchLiveLocations()
    }
    
    @objc private func handleFriendParked(_ notification: Notification) {
        guard let data = notification.object as? [String: Any] else { return }
        
        print("🅿️ LocationManager: Freund hat geparkt: \(data)")
        
        // Aktualisiere Live-Standorte
        fetchLiveLocations()
    }
    
    @objc private func handleFriendLocationUpdate(_ notification: Notification) {
        guard let data = notification.object as? [String: Any] else { return }
        
        print("📍 LocationManager: Freund-Standort aktualisiert: \(data)")
        
        // Aktualisiere Live-Standorte
        fetchLiveLocations()
    }
    
    // MARK: - User Management
    
    func setCurrentUserId(_ userId: Int) {
        currentUserId = userId
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        
        print("📍 LocationManager: Neuer Standort erhalten - \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: Standort-Fehler: \(error)")
        
        DispatchQueue.main.async {
            self.errorMessage = "Standort-Fehler: \(error.localizedDescription)"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isLocationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
            
            if self.isLocationEnabled {
                print("📍 LocationManager: Standortzugriff gewährt")
            } else {
                print("📍 LocationManager: Standortzugriff verweigert")
                self.stopLocationTracking()
            }
        }
    }
}
