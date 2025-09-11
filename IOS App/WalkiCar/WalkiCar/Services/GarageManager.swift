//
//  GarageManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import CoreBluetooth

@MainActor
class GarageManager: NSObject, ObservableObject {
    @Published var cars: [Car] = []
    @Published var bluetoothDevices: [BluetoothDevice] = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    private var centralManager: CBCentralManager?
    private var bluetoothMonitoringTimer: Timer?
    
    // Service-UUIDs für Auto-Bluetooth-Geräte (erweiterte Liste)
    private let carServiceUUIDs: [CBUUID] = [
        // Audio/Media Services
        CBUUID(string: "110A"), // Audio Source
        CBUUID(string: "110B"), // Audio Sink
        CBUUID(string: "110E"), // A2DP Advanced Audio Distribution Profile
        CBUUID(string: "111E"), // Hands-Free Profile
        CBUUID(string: "1108"), // Headset Profile
        CBUUID(string: "1105"), // Object Push Profile
        CBUUID(string: "1106"), // File Transfer Profile
        // Generic Services
        CBUUID(string: "1800"), // Generic Access Profile
        CBUUID(string: "1801"), // Generic Attribute Profile
        CBUUID(string: "180A"), // Device Information
        CBUUID(string: "180F"), // Battery Service
        // Auto-spezifische Services (falls bekannt)
        CBUUID(string: "1812"), // Human Interface Device
        CBUUID(string: "1813"), // Scan Parameters
        CBUUID(string: "1814"), // Running Speed and Cadence
        CBUUID(string: "1815"), // Cycling Speed and Cadence
    ]
    
    var activeCar: Car? {
        cars.first { $0.isActive }
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        startBluetoothMonitoring()
        
        // Prüfe sofort beim Start, ob bereits ein Auto verbunden ist
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkBluetoothConnections()
        }
    }
    
    func loadGarage() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.getGarage()
                await MainActor.run {
                    self.cars = response.cars
                    self.isLoading = false
                    
                    // Prüfe nach dem Laden der Autos, ob bereits ein Auto verbunden ist
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.checkBluetoothConnections()
                    }
                    
                    // Benachrichtige AppStateManager über geladene Garage
                    AppStateManager.shared.checkAndStartAutomaticTracking()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func createCar(name: String, brand: String?, model: String?, year: Int?, color: String?, bluetoothIdentifier: String?) {
        isLoading = true
        errorMessage = nil
        
        let request = CarCreateRequest(
            name: name,
            brand: brand,
            model: model,
            year: year,
            color: color,
            bluetoothIdentifier: bluetoothIdentifier
        )
        
        Task {
            do {
                let response = try await apiClient.createCar(request)
                await MainActor.run {
                    self.cars.append(response.car)
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
    
    func updateCar(carId: Int, name: String?, brand: String?, model: String?, year: Int?, color: String?, bluetoothIdentifier: String?) {
        isLoading = true
        errorMessage = nil
        
        let request = CarUpdateRequest(
            name: name,
            brand: brand,
            model: model,
            year: year,
            color: color,
            bluetoothIdentifier: bluetoothIdentifier,
            isActive: nil
        )
        
        Task {
            do {
                let response = try await apiClient.updateCar(carId: carId, request: request)
                await MainActor.run {
                    if let index = self.cars.firstIndex(where: { $0.id == carId }) {
                        self.cars[index] = response.car
                    }
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
    
    func deleteCar(carId: Int) {
        Task {
            do {
                try await apiClient.deleteCar(carId: carId)
                await MainActor.run {
                    self.cars.removeAll { $0.id == carId }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func setActiveCar(carId: Int) {
        Task {
            do {
                try await apiClient.setActiveCar(carId: carId)
                await MainActor.run {
                    // Aktualisiere lokale Daten
                    for i in 0..<self.cars.count {
                        if self.cars[i].id == carId {
                            // Erstelle neues Car-Objekt mit aktualisiertem isActive Status
                            let updatedCar = Car(
                                id: self.cars[i].id,
                                name: self.cars[i].name,
                                brand: self.cars[i].brand,
                                model: self.cars[i].model,
                                year: self.cars[i].year,
                                color: self.cars[i].color,
                                bluetoothIdentifier: self.cars[i].bluetoothIdentifier,
                                isActive: true,
                                createdAt: self.cars[i].createdAt,
                                updatedAt: self.cars[i].updatedAt
                            )
                            self.cars[i] = updatedCar
                            
                            // Benachrichtige LocationManager über das aktive Auto
                            LocationManager.shared.setActiveCar(carId: carId)
                            
                            // Benachrichtige AppStateManager über Auto-Aktivierung
                            AppStateManager.shared.onCarActivated(carId: carId)
                        } else {
                            // Setze alle anderen auf inaktiv
                            let updatedCar = Car(
                                id: self.cars[i].id,
                                name: self.cars[i].name,
                                brand: self.cars[i].brand,
                                model: self.cars[i].model,
                                year: self.cars[i].year,
                                color: self.cars[i].color,
                                bluetoothIdentifier: self.cars[i].bluetoothIdentifier,
                                isActive: false,
                                createdAt: self.cars[i].createdAt,
                                updatedAt: self.cars[i].updatedAt
                            )
                            self.cars[i] = updatedCar
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Location Integration
    
    func connectBluetoothAndStartTracking(carId: Int) {
        // Simuliere Bluetooth-Verbindung und starte Standort-Tracking
        Task { @MainActor in
            // Starte Standort-Tracking für das spezifische Auto
            LocationManager.shared.startLocationTracking()
            
            // Aktualisiere Standort alle 5 Sekunden für dieses Auto
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                LocationManager.shared.updateLocationToServer(carId: carId, bluetoothConnected: true)
            }
            
            print("🚗 GarageManager: Bluetooth-Verbindung und Standort-Tracking für Auto \(carId) gestartet")
        }
    }
    
    func disconnectBluetoothAndParkCar(carId: Int) {
        Task { @MainActor in
            // Stoppe Standort-Tracking und markiere Auto als geparkt
            LocationManager.shared.stopLocationTracking()
            
            // Markiere Auto als geparkt
            do {
                try await apiClient.parkCar(ParkCarRequest(carId: carId))
                print("🅿️ GarageManager: Auto \(carId) als geparkt markiert")
            } catch {
                print("❌ GarageManager: Fehler beim Parken des Autos: \(error)")
            }
        }
    }
    
    func startBluetoothScan() {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            errorMessage = "Bluetooth ist nicht verfügbar"
            return
        }
        
        isScanning = true
        bluetoothDevices = []
        
        // Hole bereits verbundene Geräte (bevorzugt)
        retrieveConnectedDevices()
        
        // Zusätzlich: Scanne nach neuen Geräten (optional)
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        // Stoppe Scan nach 10 Sekunden
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.stopBluetoothScan()
        }
    }
    
    func retrieveConnectedDevices() {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            errorMessage = "Bluetooth ist nicht verfügbar"
            return
        }
        
        // Methode 1: Hole bereits verbundene Geräte für Auto-Services
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: carServiceUUIDs)
        
        // Methode 1b: Hole ALLE verbundenen Geräte (mit leeren Services)
        let allConnectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [])
        
        print("🔵 Gefundene verbundene Bluetooth-Geräte (mit Services): \(connectedPeripherals.count)")
        print("🔵 Gefundene verbundene Bluetooth-Geräte (alle): \(allConnectedPeripherals.count)")
        
        Task { @MainActor in
            var foundConnectedDevices = 0
            
            // Füge verbundene Geräte mit bekannten Services hinzu
            for peripheral in connectedPeripherals {
                let deviceName = peripheral.name ?? "Verbundenes Auto-Gerät"
                let deviceId = peripheral.identifier.uuidString
                
                if !self.bluetoothDevices.contains(where: { $0.id == deviceId }) {
                    let device = BluetoothDevice(
                        id: deviceId,
                        name: deviceName,
                        isConnected: true,
                        signalStrength: nil
                    )
                    
                    self.bluetoothDevices.append(device)
                    foundConnectedDevices += 1
                    print("✅ Verbundenes Bluetooth-Gerät hinzugefügt: \(deviceName)")
                }
            }
            
            // Methode 2: Falls keine Geräte mit Services gefunden, prüfe alle verbundenen Geräte
            if foundConnectedDevices == 0 {
                print("ℹ️ Keine verbundenen Auto-Bluetooth-Geräte mit bekannten Services gefunden")
                print("ℹ️ Prüfe alle verbundenen Geräte...")
                
                // Füge alle anderen verbundenen Geräte hinzu
                for peripheral in allConnectedPeripherals {
                    let deviceName = peripheral.name ?? "Verbundenes Gerät"
                    let deviceId = peripheral.identifier.uuidString
                    
                    if !self.bluetoothDevices.contains(where: { $0.id == deviceId }) {
                        let device = BluetoothDevice(
                            id: deviceId,
                            name: deviceName,
                            isConnected: true,
                            signalStrength: nil
                        )
                        
                        self.bluetoothDevices.append(device)
                        foundConnectedDevices += 1
                        print("✅ Verbundenes Gerät hinzugefügt: \(deviceName)")
                    }
                }
            }
            
            // Methode 3: Falls immer noch keine verbundenen Geräte, zeige alle gescannten Geräte
            if foundConnectedDevices == 0 {
                print("ℹ️ Keine verbundenen Bluetooth-Geräte gefunden")
                print("ℹ️ Zeige alle verfügbaren Bluetooth-Geräte zur Auswahl")
                
                // Filtere gescannte Geräte nach Auto-relevanten Namen
                let autoKeywords = ["car", "auto", "vehicle", "bmw", "audi", "mercedes", "volkswagen", "ford", "toyota", "honda", "nissan", "hyundai", "kia", "seat", "skoda", "opel", "peugeot", "renault", "fiat", "alfa", "jaguar", "land rover", "mini", "smart", "tesla", "porsche", "ferrari", "lamborghini", "maserati", "bentley", "rolls", "lexus", "infiniti", "acura", "cadillac", "lincoln", "buick", "chevrolet", "gmc", "dodge", "chrysler", "jeep", "ram"]
                
                // Füge bereits gescannte Geräte hinzu, die Auto-relevant sein könnten
                for device in self.bluetoothDevices {
                    let deviceNameLower = device.name.lowercased()
                    let isAutoRelevant = autoKeywords.contains { keyword in
                        deviceNameLower.contains(keyword)
                    }
                    
                    if isAutoRelevant && !device.isConnected {
                        // Markiere als potentiell Auto-relevant
                        print("🚗 Potentiell Auto-relevantes Gerät gefunden: \(device.name)")
                    }
                }
                
                if self.bluetoothDevices.isEmpty {
                    self.errorMessage = "Keine Bluetooth-Geräte gefunden. Stelle sicher, dass Bluetooth aktiviert ist und Geräte in der Nähe sind."
                } else {
                    self.errorMessage = "Keine verbundenen Geräte gefunden. Wähle ein verfügbares Gerät aus der Liste oder verbinde dein iPhone zuerst mit dem Auto-Bluetooth."
                }
            }
        }
    }
    
    func stopBluetoothScan() {
        centralManager?.stopScan()
        isScanning = false
    }
    
    // MARK: - Bluetooth Monitoring
    
    func startBluetoothMonitoring() {
        // Überwache Bluetooth-Verbindungen alle 10 Sekunden
        bluetoothMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.checkBluetoothConnections()
        }
        print("🔵 GarageManager: Bluetooth-Überwachung gestartet")
    }
    
    func stopBluetoothMonitoring() {
        bluetoothMonitoringTimer?.invalidate()
        bluetoothMonitoringTimer = nil
        print("🔵 GarageManager: Bluetooth-Überwachung gestoppt")
    }
    
    func getConnectedPeripherals() -> [CBPeripheral] {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            return []
        }
        return centralManager.retrieveConnectedPeripherals(withServices: carServiceUUIDs)
    }
    
    private func checkBluetoothConnections() {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            print("🔵 GarageManager: Bluetooth nicht verfügbar oder ausgeschaltet")
            return
        }
        
        // Hole alle verbundenen Geräte
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: carServiceUUIDs)
        print("🔵 GarageManager: Prüfe Bluetooth-Verbindungen - \(connectedPeripherals.count) Geräte verbunden")
        
        // Prüfe ob eines der verbundenen Geräte einem Auto zugeordnet ist
        for peripheral in connectedPeripherals {
            let deviceId = peripheral.identifier.uuidString
            let deviceName = peripheral.name ?? "Unbekanntes Gerät"
            print("🔵 GarageManager: Verbundenes Gerät: \(deviceName) (ID: \(deviceId.prefix(8))...)")
            
            // Suche nach einem Auto mit dieser Bluetooth-ID
            if let car = cars.first(where: { $0.bluetoothIdentifier == deviceId }) {
                print("🚗 GarageManager: Auto gefunden: \(car.name) (ID: \(car.id))")
                
                // Auto gefunden! Prüfe ob es bereits aktiv ist
                if !car.isActive {
                    print("🚗 GarageManager: Bluetooth-Verbindung erkannt für Auto: \(car.name)")
                    print("🚗 GarageManager: Aktiviere Auto automatisch...")
                    
                    // Aktiviere das Auto automatisch
                    setActiveCar(carId: car.id)
                    
                    // Starte Standort-Tracking für dieses Auto
                    connectBluetoothAndStartTracking(carId: car.id)
                    
                    // Benachrichtige AppStateManager über Bluetooth-Verbindung
                    AppStateManager.shared.onBluetoothConnectionChanged()
                } else {
                    print("🚗 GarageManager: Auto \(car.name) ist bereits aktiv")
                }
            } else {
                print("🔵 GarageManager: Kein Auto mit Bluetooth-ID \(deviceId.prefix(8))... gefunden")
            }
        }
        
        // Prüfe auch, ob aktives Auto noch verbunden ist
        if let activeCar = activeCar, let bluetoothId = activeCar.bluetoothIdentifier {
            let isStillConnected = connectedPeripherals.contains { peripheral in
                peripheral.identifier.uuidString == bluetoothId
            }
            
            if !isStillConnected {
                print("🚗 GarageManager: Bluetooth-Verbindung zu aktivem Auto verloren: \(activeCar.name)")
                print("🚗 GarageManager: Stoppe Standort-Tracking...")
                
                // Stoppe Standort-Tracking
                disconnectBluetoothAndParkCar(carId: activeCar.id)
            }
        }
    }
    
    func setAudioDevices(carId: Int, audioDeviceNames: [String]) {
        Task {
            do {
                let updatedCar = try await apiClient.setAudioDevices(carId: carId, audioDeviceNames: audioDeviceNames)
                await MainActor.run {
                    // Aktualisiere lokale Daten
                    for i in 0..<self.cars.count {
                        if self.cars[i].id == carId {
                            self.cars[i] = updatedCar
                            break
                        }
                    }
                    print("🎵 GarageManager: Audio-Geräte für Auto ID \(carId) gesetzt: \(audioDeviceNames)")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    print("❌ GarageManager: Fehler beim Setzen der Audio-Geräte: \(error)")
                }
            }
        }
    }
    
    func getConnectedAudioDevices() -> [String] {
        // Hole verbundene Audio-Geräte vom CarAudioWatcher
        return CarAudioWatcher.shared.getConnectedAudioDevices()
    }
    
    // MARK: - CBCentralManagerDelegate

extension GarageManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("🔵 Bluetooth ist eingeschaltet")
        case .poweredOff:
            print("🔴 Bluetooth ist ausgeschaltet")
            Task { @MainActor in
                self.errorMessage = "Bluetooth ist ausgeschaltet"
            }
        case .unauthorized:
            print("🔴 Bluetooth-Berechtigung verweigert")
            Task { @MainActor in
                self.errorMessage = "Bluetooth-Berechtigung erforderlich"
            }
        case .unsupported:
            print("🔴 Bluetooth nicht unterstützt")
            Task { @MainActor in
                self.errorMessage = "Bluetooth wird nicht unterstützt"
            }
        case .resetting:
            print("🟡 Bluetooth wird zurückgesetzt")
        case .unknown:
            print("❓ Bluetooth-Status unbekannt")
        @unknown default:
            print("❓ Unbekannter Bluetooth-Status")
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unbekanntes Gerät"
        let deviceId = peripheral.identifier.uuidString
        
        // Prüfe ob das Gerät bereits in der Liste ist
        Task { @MainActor in
            if !self.bluetoothDevices.contains(where: { $0.id == deviceId }) {
                let device = BluetoothDevice(
                    id: deviceId,
                    name: deviceName,
                    isConnected: peripheral.state == .connected,
                    signalStrength: RSSI.intValue
                )
                
                self.bluetoothDevices.append(device)
                print("🔵 Bluetooth-Gerät gefunden: \(deviceName) (RSSI: \(RSSI))")
            }
        }
    }
}
