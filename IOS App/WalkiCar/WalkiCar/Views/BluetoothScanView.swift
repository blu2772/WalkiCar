//
//  BluetoothScanView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct BluetoothScanView: View {
    @ObservedObject var garageManager: GarageManager
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDevice: BluetoothDevice?
    
    init(garageManager: GarageManager, selectedDevice: Binding<BluetoothDevice?> = .constant(nil)) {
        self.garageManager = garageManager
        self._selectedDevice = selectedDevice
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Bluetooth-Geräte")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Suche nach verfügbaren Bluetooth-Geräten")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Scan Button
                    Button(action: {
                        if garageManager.isScanning {
                            garageManager.stopBluetoothScan()
                        } else {
                            garageManager.startBluetoothScan()
                        }
                    }) {
                        HStack {
                            Image(systemName: garageManager.isScanning ? "stop.fill" : "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(garageManager.isScanning ? "Scan stoppen" : "Scan starten")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(garageManager.isScanning ? Color.red : Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    
                    // Devices List
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Gefundene Geräte")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(garageManager.bluetoothDevices.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        if garageManager.bluetoothDevices.isEmpty && !garageManager.isScanning {
                            VStack(spacing: 20) {
                                Image(systemName: "bluetooth")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Keine Geräte gefunden")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Starte einen Scan um Bluetooth-Geräte zu finden")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 50)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(garageManager.bluetoothDevices) { device in
                                        BluetoothDeviceRowView(
                                            device: device,
                                            isSelected: selectedDevice?.id == device.id,
                                            onSelect: {
                                                selectedDevice = device
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        garageManager.stopBluetoothScan()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        garageManager.stopBluetoothScan()
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(selectedDevice == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            garageManager.startBluetoothScan()
        }
        .onDisappear {
            garageManager.stopBluetoothScan()
        }
    }
}

struct BluetoothDeviceRowView: View {
    let device: BluetoothDevice
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 15) {
                // Bluetooth Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "bluetooth")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("ID: \(device.id)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    if let signalStrength = device.signalStrength {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi")
                                .font(.system(size: 10))
                                .foregroundColor(signalColor)
                            
                            Text("\(signalStrength) dBm")
                                .font(.system(size: 10))
                                .foregroundColor(signalColor)
                        }
                    }
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var signalColor: Color {
        guard let signalStrength = device.signalStrength else { return .gray }
        
        if signalStrength > -50 {
            return .green
        } else if signalStrength > -70 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    BluetoothScanView(garageManager: GarageManager())
}
