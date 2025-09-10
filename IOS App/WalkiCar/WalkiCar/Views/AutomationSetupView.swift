//
//  AutomationSetupView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct AutomationSetupView: View {
    let carName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "gear.badge")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Bluetooth-Automatisierung")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Richte automatisches Standort-Tracking für '\(carName)' ein")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Steps
                        VStack(spacing: 20) {
                            AutomationStepView(
                                stepNumber: 1,
                                title: "Shortcuts-App öffnen",
                                description: "Öffne die Shortcuts-App auf deinem iPhone",
                                action: "Shortcuts öffnen",
                                actionColor: .blue
                            ) {
                                openShortcutsApp()
                            }
                            
                            AutomationStepView(
                                stepNumber: 2,
                                title: "Automatisierung erstellen",
                                description: "Tippe auf 'Automatisierung' und dann auf '+'",
                                action: nil,
                                actionColor: nil
                            )
                            
                            AutomationStepView(
                                stepNumber: 3,
                                title: "Bluetooth-Trigger wählen",
                                description: "Wähle 'Bluetooth' als Trigger und wähle dein Auto-Gerät",
                                action: nil,
                                actionColor: nil
                            )
                            
                            AutomationStepView(
                                stepNumber: 4,
                                title: "URL-Aktion hinzufügen",
                                description: "Füge eine 'URL öffnen' Aktion hinzu mit der URL:",
                                action: nil,
                                actionColor: nil
                            )
                            
                            // URL Template
                            VStack(alignment: .leading, spacing: 8) {
                                Text("URL-Template:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("walkicar://bluetooth/connected?carId=1")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Text("Ersetze 'carId=1' mit der ID deines Autos")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 20)
                            
                            AutomationStepView(
                                stepNumber: 5,
                                title: "Automatisierung aktivieren",
                                description: "Aktiviere die Automatisierung und erlaube Benachrichtigungen",
                                action: nil,
                                actionColor: nil
                            )
                        }
                        
                        // Info Box
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("Wie es funktioniert")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Bei Bluetooth-Verbindung: Auto wird aktiviert und Standort-Tracking startet")
                                Text("• Bei Bluetooth-Trennung: Standort-Tracking stoppt und Auto wird geparkt")
                                Text("• Alles passiert automatisch - keine manuelle Bedienung nötig")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func openShortcutsApp() {
        AutomationService.shared.openShortcutsApp()
    }
}

struct AutomationStepView: View {
    let stepNumber: Int
    let title: String
    let description: String
    let action: String?
    let actionColor: Color?
    let actionHandler: (() -> Void)?
    
    init(stepNumber: Int, title: String, description: String, action: String?, actionColor: Color?, actionHandler: (() -> Void)? = nil) {
        self.stepNumber = stepNumber
        self.title = title
        self.description = description
        self.action = action
        self.actionColor = actionColor
        self.actionHandler = actionHandler
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Step Number
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    
                    Text("\(stepNumber)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
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
            
            // Action Button
            if let action = action, let actionColor = actionColor, let actionHandler = actionHandler {
                Button(action: actionHandler) {
                    Text(action)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(actionColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    AutomationSetupView(carName: "Mein Auto")
}
