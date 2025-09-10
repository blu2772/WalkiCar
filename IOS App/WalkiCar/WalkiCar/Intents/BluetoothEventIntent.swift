//
//  BluetoothEventIntent.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import AppIntents
import Foundation

struct BluetoothEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Bluetooth Event"
    static var description = IntentDescription("Reagiert auf Bluetooth Verbinden/Trennen von Kurzbefehle.")
    
    @Parameter(title: "Gerätename")
    var deviceName: String
    
    @Parameter(title: "Ereignis", default: "connected")
    var event: String // "connected" | "disconnected"
    
    @Parameter(title: "Auto ID")
    var carId: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Bluetooth \(\.$event) für \(\.$deviceName) (Auto ID: \(\.$carId))")
    }
    
    func perform() async throws -> some IntentResult {
        print("🔵 BluetoothEventIntent: \(event) für \(deviceName) (Auto ID: \(carId))")
        
        // Benachrichtige AppStateManager über Bluetooth-Event
        await MainActor.run {
            if event == "connected" {
                AppStateManager.shared.onBluetoothConnected(deviceId: deviceName, carId: carId)
            } else {
                AppStateManager.shared.onBluetoothDisconnected(deviceId: deviceName, carId: carId)
            }
        }
        
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct WalkiCarShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BluetoothEventIntent(),
            phrases: [
                "Bluetooth Event in WalkiCar",
                "Auto Bluetooth Event"
            ],
            shortTitle: "Bluetooth Event",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
    }
}
