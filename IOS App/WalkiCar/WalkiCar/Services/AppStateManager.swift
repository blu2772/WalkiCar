//
//  AppStateManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import UIKit

@MainActor
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var garageManager: GarageManager?
    @Published var locationManager: LocationManager?
    @Published var isAppActive = true
    
    private var trackingCheckCount = 0
    private let maxTrackingChecks = 3
    
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
        // Verwende den Singleton GarageManager
        self.garageManager = GarageManager.shared
        self.locationManager = locationManager
        print("🏠 AppStateManager: Manager gesetzt")
        
        // Starte automatisches Tracking beim ersten Setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.checkAndStartAutomaticTracking()
        }
    }
    
    func checkAndStartAutomaticTracking() {
        // Begrenze die Anzahl der Tracking-Checks
        trackingCheckCount += 1
        if trackingCheckCount > maxTrackingChecks {
            print("🏠 AppStateManager: Maximale Anzahl von Tracking-Checks erreicht - stoppe")
            return
        }
        
        guard let garageManager = garageManager,
              let locationManager = locationManager else {
            print("🏠 AppStateManager: Manager noch nicht verfügbar")
            return
        }
        
        // Prüfe ob Garage bereits geladen ist
        guard !garageManager.cars.isEmpty else {
            print("🏠 AppStateManager: Garage noch nicht geladen - warte... (Garage hat \(garageManager.cars.count) Autos)")
            // Warte kurz und versuche es erneut (nur einmal)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkAndStartAutomaticTracking()
            }
            return
        }
        
        // Prüfe ob ein Auto aktiv ist
        guard let activeCar = garageManager.activeCar else {
            print("🏠 AppStateManager: Kein aktives Auto")
            return
        }
        
        // Setze aktives Auto im LocationManager
        locationManager.setActiveCar(carId: activeCar.id)
        
        // Prüfe ob bereits getrackt wird
        guard !locationManager.isTracking else {
            print("🏠 AppStateManager: Tracking läuft bereits")
            return
        }
        
        // Prüfe Audio-Verbindung
        if let audioDevices = activeCar.audioDeviceNames {
            let connectedAudioDevices = CarAudioWatcher.shared.getConnectedAudioDevices()
            let isAudioConnected = connectedAudioDevices.contains { deviceName in
                audioDevices.contains(deviceName)
            }
            
            if isAudioConnected {
                print("🏠 AppStateManager: Automatisches Tracking gestartet für Auto: \(activeCar.name)")
                locationManager.startLocationTracking()
            } else {
                print("🏠 AppStateManager: Auto nicht über Audio verbunden")
            }
        }
    }
    
    func onCarActivated(carId: Int) {
        guard let locationManager = locationManager else { return }
        
        // Reset Tracking-Check-Counter
        trackingCheckCount = 0
        
        locationManager.setActiveCar(carId: carId)
        
        // Prüfe sofort nach Aktivierung
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAndStartAutomaticTracking()
        }
    }
    
    func onAudioRouteChanged(connectedDevices: [String]) {
        guard let garageManager = garageManager,
              let locationManager = locationManager else {
            print("🏠 AppStateManager: Manager noch nicht verfügbar für Audio-Route-Änderung")
            return
        }
        
        // Reset Tracking-Check-Counter bei Audio-Route-Änderung
        trackingCheckCount = 0
        
        // Prüfe ob Garage bereits geladen ist
        guard !garageManager.cars.isEmpty else {
            print("🏠 AppStateManager: Garage noch nicht geladen für Audio-Route-Änderung - warte... (Garage hat \(garageManager.cars.count) Autos)")
            // Warte kurz und versuche es erneut
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.onAudioRouteChanged(connectedDevices: connectedDevices)
            }
            return
        }
        
        print("🏠 AppStateManager: Audio-Route geändert - \(connectedDevices.count) Geräte verbunden")
        for device in connectedDevices {
            print("🎵 AppStateManager: Verbundenes Audio-Gerät: \(device)")
        }
        
        // Prüfe ob eines der verbundenen Audio-Geräte einem Auto zugeordnet ist
        var foundActiveCar = false
        for deviceName in connectedDevices {
            if let car = garageManager.cars.first(where: { car in
                car.audioDeviceNames?.contains(deviceName) == true
            }) {
                print("🚗 AppStateManager: Audio-Gerät '\(deviceName)' gehört zu Auto '\(car.name)'")
                
                if !car.isActive {
                    print("🚗 AppStateManager: Aktiviere Auto automatisch über Audio-Verbindung...")
                    garageManager.setActiveCar(carId: car.id)
                    
                    // Setze aktives Auto im LocationManager
                    locationManager.setActiveCar(carId: car.id)
                    
                    // Starte Standort-Tracking
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        locationManager.startLocationTracking()
                        print("🚗 AppStateManager: Standort-Tracking für Auto '\(car.name)' gestartet")
                    }
                } else {
                    print("🚗 AppStateManager: Auto '\(car.name)' ist bereits aktiv")
                    
                    // Setze aktives Auto im LocationManager
                    locationManager.setActiveCar(carId: car.id)
                    
                    // Prüfe ob Standort-Tracking läuft
                    if !locationManager.isTracking {
                        print("🚗 AppStateManager: Starte Standort-Tracking für bereits aktives Auto...")
                        locationManager.startLocationTracking()
                        print("🚗 AppStateManager: Standort-Tracking für Auto '\(car.name)' gestartet")
                    } else {
                        print("🚗 AppStateManager: Standort-Tracking läuft bereits")
                    }
                }
                foundActiveCar = true
                break // Nur ein Auto kann aktiv sein
            }
        }
        
        // Prüfe auch, ob aktives Auto noch über Audio verbunden ist
        if let activeCar = garageManager.activeCar,
           let audioDevices = activeCar.audioDeviceNames {
            let isStillConnected = connectedDevices.contains { deviceName in
                audioDevices.contains(deviceName)
            }
            
            if !isStillConnected && !foundActiveCar {
                print("🚗 AppStateManager: Audio-Verbindung zu aktivem Auto verloren: \(activeCar.name)")
                print("🚗 AppStateManager: Parke Auto und stoppe Standort-Tracking...")
                
                // Parke das Auto
                Task {
                    do {
                        let parkRequest = ParkCarRequest(carId: activeCar.id)
                        try await APIClient.shared.parkCar(parkRequest)
                        print("🚗 AppStateManager: Auto '\(activeCar.name)' erfolgreich geparkt")
                    } catch {
                        print("❌ AppStateManager: Fehler beim Parken des Autos: \(error)")
                    }
                }
                
                // Stoppe Standort-Tracking
                locationManager.stopLocationTracking()
                
                // Setze Auto auf inaktiv
                garageManager.setActiveCar(carId: -1) // -1 bedeutet kein aktives Auto
            }
        }
    }
}
