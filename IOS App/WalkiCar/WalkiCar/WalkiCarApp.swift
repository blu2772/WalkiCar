//
//  WalkiCarApp.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import UserNotifications

@main
struct WalkiCarApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var garageManager = GarageManager()
    @StateObject private var locationManager = LocationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(garageManager)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Initialisiere AppStateManager mit den Managern
                    AppStateManager.shared.setManagers(
                        garageManager: garageManager,
                        locationManager: locationManager
                    )
                    
                    // Setze AutomationService Callbacks
                    AutomationService.shared.onBluetoothConnected = { carId, deviceId in
                        Task { @MainActor in
                            garageManager.setActiveCar(carId: carId)
                            locationManager.startLocationTracking()
                        }
                    }
                    
                    AutomationService.shared.onBluetoothDisconnected = { carId, deviceId in
                        Task { @MainActor in
                            locationManager.stopLocationTracking()
                        }
                    }
                }
                .onOpenURL { url in
                    // Handle URL-Scheme für Apple Automatisierung
                    _ = AutomationService.shared.handleAutomationURL(url)
                }
        }
    }
}
