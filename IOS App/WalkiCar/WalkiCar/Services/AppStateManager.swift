//
//  AppStateManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import CoreBluetooth
import UIKit

@MainActor
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var garageManager: GarageManager?
    @Published var locationManager: LocationManager?
    @Published var isAppActive = true
    
    private init() {
        setupAppLifecycle()
    }
    
    private func setupAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        print("🏠 AppStateManager: App-Lifecycle-Überwachung gestartet")
    }
    
    @objc private func appDidBecomeActive() {
        isAppActive = true
        print("🏠 AppStateManager: App wurde aktiv")
        checkAndStartAutomaticTracking()
    }
    
    @objc private func appDidEnterBackground() {
        isAppActive = false
        print("🏠 AppStateManager: App im Hintergrund")
    }
    
    func setManagers(garageManager: GarageManager, locationManager: LocationManager) {
        self.garageManager = garageManager
        self.locationManager = locationManager
        print("🏠 AppStateManager: Manager gesetzt")
        
        // Starte automatisches Tracking beim ersten Setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.checkAndStartAutomaticTracking()
        }
    }
    
    func checkAndStartAutomaticTracking() {
        guard let garageManager = garageManager,
              let locationManager = locationManager else {
            print("🏠 AppStateManager: Manager noch nicht verfügbar")
            return
        }
        
        // Prüfe ob Garage bereits geladen ist
        guard !garageManager.cars.isEmpty else {
            print("🏠 AppStateManager: Garage noch nicht geladen - warte...")
            return
        }
        
        // Prüfe ob ein Auto aktiv ist
        guard let activeCar = garageManager.activeCar else {
            print("🏠 AppStateManager: Kein aktives Auto")
            return
        }
        
        // Prüfe ob bereits getrackt wird
        guard !locationManager.isTracking else {
            print("🏠 AppStateManager: Tracking läuft bereits")
            return
        }
        
        // Prüfe Bluetooth-Verbindung
        let connectedPeripherals = garageManager.getConnectedPeripherals()
        
        if let bluetoothId = activeCar.bluetoothIdentifier {
            let isConnected = connectedPeripherals.contains { peripheral in
                peripheral.identifier.uuidString == bluetoothId
            }
            
            if isConnected {
                print("🏠 AppStateManager: Automatisches Tracking gestartet für Auto: \(activeCar.name)")
                locationManager.startLocationTracking()
            } else {
                print("🏠 AppStateManager: Auto nicht über Bluetooth verbunden")
            }
        }
    }
    
    func onCarActivated(carId: Int) {
        guard let locationManager = locationManager else { return }
        
        locationManager.setActiveCar(carId: carId)
        
        // Prüfe sofort nach Aktivierung
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAndStartAutomaticTracking()
        }
    }
    
    func onBluetoothConnectionChanged() {
        // Prüfe automatisches Tracking bei Bluetooth-Änderungen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkAndStartAutomaticTracking()
        }
    }
    
    // MARK: - Shortcuts Integration
    
    func onBluetoothConnected(deviceId: String, carId: Int) {
        guard let garageManager = garageManager,
              let locationManager = locationManager else {
            print("🏠 AppStateManager: Manager noch nicht verfügbar für Bluetooth-Verbindung")
            return
        }
        
        print("🏠 AppStateManager: Bluetooth-Verbindung über Shortcut erkannt - Car ID: \(carId)")
        
        // Aktiviere das Auto
        garageManager.setActiveCar(carId: carId)
        
        // Starte Standort-Tracking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            locationManager.startLocationTracking()
            print("🏠 AppStateManager: Standort-Tracking für Auto \(carId) gestartet")
        }
    }
    
    func onBluetoothDisconnected(deviceId: String, carId: Int) {
        guard let locationManager = locationManager else {
            print("🏠 AppStateManager: LocationManager noch nicht verfügbar für Bluetooth-Trennung")
            return
        }
        
        print("🏠 AppStateManager: Bluetooth-Trennung über Shortcut erkannt - Car ID: \(carId)")
        
        // Stoppe Standort-Tracking
        locationManager.stopLocationTracking()
        print("🏠 AppStateManager: Standort-Tracking für Auto \(carId) gestoppt")
    }
}
