//
//  AutomationService.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import UIKit

class AutomationService: ObservableObject {
    static let shared = AutomationService()
    
    // Callbacks für Manager-Updates
    var onBluetoothConnected: ((Int, String?) -> Void)?
    var onBluetoothDisconnected: ((Int, String?) -> Void)?
    
    private init() {}
    
    // MARK: - URL Scheme Handling
    
    func handleAutomationURL(_ url: URL) -> Bool {
        print("🔗 AutomationService: URL empfangen: \(url.absoluteString)")
        
        guard url.scheme == "walkicar" else {
            print("❌ AutomationService: Unbekanntes URL-Scheme: \(url.scheme ?? "nil")")
            return false
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let action = components?.path.replacingOccurrences(of: "/", with: "") // "connected" oder "disconnected"
        let deviceId = components?.queryItems?.first(where: { $0.name == "deviceId" })?.value
        let carIdString = components?.queryItems?.first(where: { $0.name == "carId" })?.value
        let carId = carIdString.flatMap { Int($0) }
        
        print("🔗 AutomationService: Action: \(action ?? "nil"), DeviceID: \(deviceId ?? "nil"), CarID: \(carId ?? -1)")
        
        Task { @MainActor in
            if action == "connected" {
                await handleBluetoothConnected(carId: carId, deviceId: deviceId)
            } else if action == "disconnected" {
                await handleBluetoothDisconnected(carId: carId, deviceId: deviceId)
            } else {
                print("❌ AutomationService: Unbekannte Aktion: \(action ?? "nil")")
            }
        }
        
        return true
    }
    
    @MainActor
    private func handleBluetoothConnected(carId: Int?, deviceId: String?) async {
        print("🔗 AutomationService: Bluetooth verbunden - CarID: \(carId ?? -1)")
        
        guard let carId = carId else {
            print("❌ AutomationService: Keine CarID für Bluetooth-Verbindung")
            return
        }
        
        // Backend über Bluetooth-Event benachrichtigen
        await notifyBackendBluetoothEvent(action: "connected", carId: carId, deviceId: deviceId)
        
        // Lokale Manager über Callback benachrichtigen
        onBluetoothConnected?(carId, deviceId)
        
        // Benachrichtigung anzeigen
        showNotification(title: "Auto verbunden", body: "Standort-Tracking gestartet")
    }
    
    @MainActor
    private func handleBluetoothDisconnected(carId: Int?, deviceId: String?) async {
        print("🔗 AutomationService: Bluetooth getrennt - CarID: \(carId ?? -1)")
        
        guard let carId = carId else {
            print("❌ AutomationService: Keine CarID für Bluetooth-Trennung")
            return
        }
        
        // Backend über Bluetooth-Event benachrichtigen
        await notifyBackendBluetoothEvent(action: "disconnected", carId: carId, deviceId: deviceId)
        
        // Lokale Manager über Callback benachrichtigen
        onBluetoothDisconnected?(carId, deviceId)
        
        // Benachrichtigung anzeigen
        showNotification(title: "Auto getrennt", body: "Standort-Tracking gestoppt")
    }
    
    // MARK: - Backend Communication
    
    private func notifyBackendBluetoothEvent(action: String, carId: Int, deviceId: String?) async {
        do {
            let request = BluetoothEventRequest(
                action: action,
                carId: carId,
                deviceId: deviceId,
                timestamp: Date()
            )
            
            let response: [String: String] = try await APIClient.shared.makeRequest(
                endpoint: "/automation/bluetooth-event",
                method: "POST",
                body: request,
                responseType: [String: String].self
            )
            
            print("✅ AutomationService: Backend benachrichtigt - \(response["message"] ?? "OK")")
            
        } catch {
            print("❌ AutomationService: Fehler beim Benachrichtigen des Backends: \(error)")
        }
    }
    
    // MARK: - Template Generation
    
    func getAutomationTemplate(for carId: Int) async -> AutomationTemplate? {
        do {
            let template: AutomationTemplate = try await APIClient.shared.makeRequest(
                endpoint: "/automation/car/\(carId)/template",
                method: "GET",
                responseType: AutomationTemplate.self
            )
            
            return template
            
        } catch {
            print("❌ AutomationService: Fehler beim Laden des Templates: \(error)")
            return nil
        }
    }
    
    // MARK: - Notifications
    
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Shortcuts App Integration
    
    func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
    
    func openAutomationSetup() {
        if let url = URL(string: "shortcuts://automation") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Data Models

struct BluetoothEventRequest: Codable {
    let action: String
    let carId: Int
    let deviceId: String?
    let timestamp: Date
}

struct AutomationTemplate: Codable {
    let car: CarInfo
    let templates: URLTemplates
    let instructions: Instructions
}

struct CarInfo: Codable {
    let id: Int
    let name: String
}

struct URLTemplates: Codable {
    let connected: String
    let disconnected: String
}

struct Instructions: Codable {
    let title: String
    let steps: [String]
}
