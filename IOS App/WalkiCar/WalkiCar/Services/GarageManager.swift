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
    
    var activeCar: Car? {
        cars.first { $0.isActive }
    }
    
    override init() {
        super.init()
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
        
        // Scanne nach verfügbaren Bluetooth-Geräten
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        // Stoppe Scan nach 10 Sekunden
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.stopBluetoothScan()
        }
    }
    
    func stopBluetoothScan() {
        centralManager?.stopScan()
        isScanning = false
    }
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
