//
//  ShortcutSetupView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import AppIntents

struct ShortcutSetupView: View {
    let car: Car
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Bluetooth Shortcut einrichten")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Für \(car.name)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionStep(
                            number: 1,
                            title: "Shortcuts App öffnen",
                            description: "Öffne die Shortcuts App auf deinem iPhone"
                        )
                        
                        InstructionStep(
                            number: 2,
                            title: "Persönliche Automation erstellen",
                            description: "Tippe auf 'Automation' → 'Persönliche Automation erstellen'"
                        )
                        
                        InstructionStep(
                            number: 3,
                            title: "Bluetooth Trigger wählen",
                            description: "Wähle 'Bluetooth' → 'Wenn ich eine Verbindung zu einem Gerät herstelle'"
                        )
                        
                        InstructionStep(
                            number: 4,
                            title: "Gerät auswählen",
                            description: "Wähle dein Auto-Bluetooth-Gerät aus der Liste"
                        )
                        
                        InstructionStep(
                            number: 5,
                            title: "WalkiCar Aktion hinzufügen",
                            description: "Füge 'WalkiCar: Bluetooth Event' hinzu und konfiguriere:"
                        )
                        
                        // Configuration Details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Konfiguration:")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ConfigItem(title: "Gerätename:", value: car.name)
                            ConfigItem(title: "Ereignis:", value: "connected")
                            ConfigItem(title: "Auto ID:", value: "\(car.id)")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        InstructionStep(
                            number: 6,
                            title: "Automation aktivieren",
                            description: "Schalte 'Vor Ausführen fragen' aus und tippe 'Fertig'"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: openShortcutsApp) {
                            HStack {
                                Image(systemName: "app.badge")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Shortcuts App öffnen")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Button(action: { dismiss() }) {
                            Text("Fertig")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
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
        .preferredColorScheme(.dark)
    }
    
    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step Number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

struct ConfigItem: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ShortcutSetupView(car: Car(
        id: 1,
        name: "Mein Auto",
        brand: "BMW",
        model: "X5",
        year: 2020,
        color: "Schwarz",
        bluetoothIdentifier: "ABC123",
        isActive: true,
        createdAt: "2025-01-01T00:00:00Z",
        updatedAt: "2025-01-01T00:00:00Z"
    ))
}
