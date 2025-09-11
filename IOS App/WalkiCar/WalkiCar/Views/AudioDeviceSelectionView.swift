//
//  AudioDeviceSelectionView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct AudioDeviceSelectionView: View {
    @ObservedObject var garageManager = GarageManager.shared
    @ObservedObject var audioWatcher: CarAudioWatcher
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDevices: Set<String> = []
    @State private var isLoading = false
    
    let car: Car
    let onDevicesSelected: ([String]) -> Void
    
    init(audioWatcher: CarAudioWatcher, car: Car, onDevicesSelected: @escaping ([String]) -> Void) {
        self.audioWatcher = audioWatcher
        self.car = car
        self.onDevicesSelected = onDevicesSelected
        
        // Initialisiere mit bereits zugeordneten Geräten
        self._selectedDevices = State(initialValue: Set(car.audioDeviceNames ?? []))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Audio-Geräte zuordnen")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Wähle die Audio-Geräte aus, die zu '\(car.name)' gehören")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Info Box
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            
                            Text("Tipp")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        
                        Text("Verbinde dein iPhone mit dem Auto-Audio und wähle dann das entsprechende Gerät aus der Liste aus.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Audio Devices List
                    if audioWatcher.connectedAudioDevices.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "speaker.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("Keine Audio-Geräte verbunden")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text("Verbinde dein iPhone mit einem Auto-Audio-Gerät und kehre hierher zurück.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(audioWatcher.connectedAudioDevices, id: \.self) { deviceName in
                                    AudioDeviceRow(
                                        deviceName: deviceName,
                                        isSelected: selectedDevices.contains(deviceName),
                                        onToggle: { toggleDevice(deviceName) }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Save Button
                        Button(action: saveDevices) {
                            HStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Audio-Geräte zuordnen")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedDevices.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(selectedDevices.isEmpty || isLoading)
                        
                        // Clear Button
                        if !selectedDevices.isEmpty {
                            Button(action: clearSelection) {
                                HStack {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("Auswahl löschen")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            // Stelle sicher, dass Audio-Überwachung läuft
            if !audioWatcher.isMonitoring {
                audioWatcher.startMonitoring()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func toggleDevice(_ deviceName: String) {
        if selectedDevices.contains(deviceName) {
            selectedDevices.remove(deviceName)
        } else {
            selectedDevices.insert(deviceName)
        }
    }
    
    private func clearSelection() {
        selectedDevices.removeAll()
    }
    
    private func saveDevices() {
        isLoading = true
        
        let deviceNames = Array(selectedDevices)
        
        Task {
            await MainActor.run {
                garageManager.setAudioDevices(carId: car.id, audioDeviceNames: deviceNames)
                onDevicesSelected(deviceNames)
                dismiss()
            }
        }
    }
}

struct AudioDeviceRow: View {
    let deviceName: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text(deviceName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    AudioDeviceSelectionView(
        audioWatcher: CarAudioWatcher.shared,
        car: Car(
            id: 1,
            name: "Mein Auto",
            brand: "BMW",
            model: "X5",
            year: 2020,
            color: "Schwarz",
            bluetoothIdentifier: nil,
            audioDeviceNames: ["BMW 330e"],
            isActive: true,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z"
        ),
        onDevicesSelected: { _ in }
    )
}
