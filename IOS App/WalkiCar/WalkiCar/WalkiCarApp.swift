//
//  WalkiCarApp.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

@main
struct WalkiCarApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var garageManager = GarageManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var audioWatcher = CarAudioWatcher.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(garageManager)
                .environmentObject(locationManager)
                .environmentObject(audioWatcher)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Initialisiere AppStateManager mit den Managern
                    AppStateManager.shared.setManagers(
                        garageManager: garageManager,
                        locationManager: locationManager
                    )
                    
                    // Starte Audio-Route-Überwachung
                    audioWatcher.startMonitoring()
                }
        }
    }
}
