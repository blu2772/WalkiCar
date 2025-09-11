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
    static let shared = GarageManager()
    
    @Published var cars: [Car] = []
    @Published var carsWithLocations: [CarWithLocation] = []
    @Published var bluetoothDevices: [BluetoothDevice] = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    private var centralManager: CBCentralManager?
    
    var activeCar: Car? {
        cars.first { $0.isActive }
    }
    
    private override init() {
        super.init()
        // Nur für Bluetooth-Scanning, nicht für Monitoring
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
                    
                    print("🚗 GarageManager: Garage geladen - \(self.cars.count) Autos")
                    for car in self.cars {
                        print("🚗 GarageManager: Auto '\(car.name)' - Aktiv: \(car.isActive), Audio-Geräte: \(car.audioDeviceNames ?? [])")
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
    
    func loadCarsWithLocations() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.getCarsWithLocations()
                await MainActor.run {
                    self.carsWithLocations = response.cars
                    self.isLoading = false
                    
                    print("🚗 GarageManager: Autos mit Standorten geladen - \(self.carsWithLocations.count) Autos")
                    for car in self.carsWithLocations {
                        let locationInfo = car.hasLocation ? "Standort: \(car.latitude ?? 0), \(car.longitude ?? 0)" : "Kein Standort"
                        print("🚗 GarageManager: Auto '\(car.name)' - Status: \(car.statusText), \(locationInfo)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Fehler beim Laden der Autos mit Standorten: \(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ GarageManager: Fehler beim Laden der Autos mit Standorten: \(error)")
                }
            }
        }
    }
    
    func createCar(name: String, brand: String?, model: String?, year: Int?, color: String?, bluetoothIdentifier: String?, audioDeviceNames: [String]? = nil) {
        isLoading = true
        errorMessage = nil
        
        let request = CarCreateRequest(
            name: name,
            brand: brand,
            model: model,
            year: year,
            color: color,
            bluetoothIdentifier: bluetoothIdentifier,
            audioDeviceNames: audioDeviceNames
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
    
    func updateCar(carId: Int, name: String?, brand: String?, model: String?, year: Int?, color: String?, bluetoothIdentifier: String?, audioDeviceNames: [String]?) {
        isLoading = true
        errorMessage = nil
        
        let request = CarUpdateRequest(
            name: name,
            brand: brand,
            model: model,
            year: year,
            color: color,
            bluetoothIdentifier: bluetoothIdentifier,
            audioDeviceNames: audioDeviceNames,
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
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await apiClient.deleteCar(carId: carId)
                await MainActor.run {
                    self.cars.removeAll { $0.id == carId }
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
    
    func setActiveCar(carId: Int) {
        // Spezialfall: -1 bedeutet kein aktives Auto
        if carId == -1 {
            Task {
                await MainActor.run {
                    // Setze alle Autos auf inaktiv
                    for i in 0..<self.cars.count {
                        let updatedCar = Car(
                            id: self.cars[i].id,
                            name: self.cars[i].name,
                            brand: self.cars[i].brand,
                            model: self.cars[i].model,
                            year: self.cars[i].year,
                            color: self.cars[i].color,
                            bluetoothIdentifier: self.cars[i].bluetoothIdentifier,
                            audioDeviceNames: self.cars[i].audioDeviceNames,
                            isActive: false,
                            createdAt: self.cars[i].createdAt,
                            updatedAt: self.cars[i].updatedAt
                        )
                        self.cars[i] = updatedCar
                    }
                    print("🚗 GarageManager: Alle Autos auf inaktiv gesetzt")
                }
            }
            return
        }
        
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
                                audioDeviceNames: self.cars[i].audioDeviceNames,
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
                                audioDeviceNames: self.cars[i].audioDeviceNames,
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
                    print("❌ GarageManager: Fehler beim Setzen des aktiven Autos: \(error)")
                }
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
    
    // MARK: - Bluetooth Scanning (nur für manuelle Geräte-Auswahl)
    
    func startBluetoothScan() {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            print("🔵 Bluetooth nicht verfügbar")
            return
        }
        
        bluetoothDevices.removeAll()
        isScanning = true
        
        // Scanne nach allen verfügbaren Geräten
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        print("🔵 Bluetooth-Scan gestartet")
    }
    
    func stopBluetoothScan() {
        centralManager?.stopScan()
        isScanning = false
    }
    
    // MARK: - CBCentralManagerDelegate
}

extension GarageManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("🔵 Bluetooth ist eingeschaltet")
        case .poweredOff:
            print("🔵 Bluetooth ist ausgeschaltet")
        case .resetting:
            print("🔵 Bluetooth wird zurückgesetzt")
        case .unauthorized:
            print("🔵 Bluetooth-Berechtigung verweigert")
        case .unsupported:
            print("🔵 Bluetooth nicht unterstützt")
        case .unknown:
            print("🔵 Bluetooth-Status unbekannt")
        @unknown default:
            print("🔵 Unbekannter Bluetooth-Status")
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