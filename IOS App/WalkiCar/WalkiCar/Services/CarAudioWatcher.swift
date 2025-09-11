//
//  CarAudioWatcher.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class CarAudioWatcher: ObservableObject {
    static let shared = CarAudioWatcher()
    
    @Published var connectedAudioDevices: [String] = []
    @Published var isMonitoring = false
    
    private let session = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // Ambient-Kategorie erlaubt Mischen mit anderen Apps
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            print("🎵 CarAudioWatcher: Audio-Session konfiguriert")
        } catch {
            print("❌ CarAudioWatcher: Audio-Session-Fehler: \(error)")
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Route-Change-Überwachung starten
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        isMonitoring = true
        print("🎵 CarAudioWatcher: Audio-Route-Überwachung gestartet")
        
        // Beim Start einmal abfragen
        handleRouteChanged()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        isMonitoring = false
        print("🎵 CarAudioWatcher: Audio-Route-Überwachung gestoppt")
    }
    
    @objc private func handleRouteChanged() {
        let outputs = session.currentRoute.outputs
        let btOutputs = outputs.filter { output in
            output.portType == .bluetoothA2DP || 
            output.portType == .bluetoothHFP || 
            output.portType == .bluetoothLE
        }
        
        let deviceNames = btOutputs.map { $0.portName }
        
        print("🎵 CarAudioWatcher: Route geändert - \(deviceNames.count) Bluetooth-Audio-Geräte")
        for device in deviceNames {
            print("🎵 CarAudioWatcher: Verbundenes Audio-Gerät: \(device)")
        }
        
        connectedAudioDevices = deviceNames
        
        // Benachrichtige AppStateManager über Audio-Änderungen
        AppStateManager.shared.onAudioRouteChanged(connectedDevices: deviceNames)
    }
    
    func getConnectedAudioDevices() -> [String] {
        return connectedAudioDevices
    }
    
    deinit {
        Task { @MainActor in
            stopMonitoring()
        }
    }
}
