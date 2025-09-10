//
//  TemplateShareView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import UIKit

struct TemplateShareView: View {
    let carId: Int
    let carName: String
    @Environment(\.dismiss) private var dismiss
    @State private var isGenerating = false
    @State private var showingShareSheet = false
    @State private var shareItems: [URL] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Shortcut-Templates erstellen")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Erstelle automatische Shortcuts für '\(carName)'")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Info Box
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("Was passiert?")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Zwei Shortcut-Dateien werden erstellt")
                                Text("• 'Verbunden' - startet Standort-Tracking")
                                Text("• 'Getrennt' - stoppt Standort-Tracking")
                                Text("• Importiere sie in die Shortcuts-App")
                                Text("• Wähle dein Bluetooth-Gerät als Trigger")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Template Buttons
                        VStack(spacing: 16) {
                            Button(action: generateAndShareTemplates) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(isGenerating ? "Erstelle Templates..." : "Templates erstellen & teilen")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(isGenerating)
                            
                            Button(action: openShortcutsApp) {
                                HStack {
                                    Image(systemName: "gear")
                                        .foregroundColor(.white)
                                    
                                    Text("Shortcuts-App öffnen")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Anleitung:")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                InstructionStepView(
                                    stepNumber: 1,
                                    title: "Templates teilen",
                                    description: "Tippe auf 'Templates erstellen & teilen' und wähle 'In Shortcuts öffnen'"
                                )
                                
                                InstructionStepView(
                                    stepNumber: 2,
                                    title: "Automatisierung einrichten",
                                    description: "Gehe zu 'Automatisierung' → '+' → 'Bluetooth'"
                                )
                                
                                InstructionStepView(
                                    stepNumber: 3,
                                    title: "Gerät auswählen",
                                    description: "Wähle dein Auto-Bluetooth-Gerät aus der Liste"
                                )
                                
                                InstructionStepView(
                                    stepNumber: 4,
                                    title: "Shortcut hinzufügen",
                                    description: "Füge den entsprechenden Shortcut hinzu (Verbunden/Getrennt)"
                                )
                                
                                InstructionStepView(
                                    stepNumber: 5,
                                    title: "Automatisierung aktivieren",
                                    description: "Aktiviere die Automatisierung und erlaube Benachrichtigungen"
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .preferredColorScheme(.dark)
    }
    
    private func generateAndShareTemplates() {
        isGenerating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let connectedURL = ShortcutTemplateGenerator.shared.createConnectedTemplateFile(carId: carId, carName: carName),
                  let disconnectedURL = ShortcutTemplateGenerator.shared.createDisconnectedTemplateFile(carId: carId, carName: carName) else {
                DispatchQueue.main.async {
                    isGenerating = false
                }
                return
            }
            
            DispatchQueue.main.async {
                shareItems = [connectedURL, disconnectedURL]
                isGenerating = false
                showingShareSheet = true
            }
        }
    }
    
    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
}

struct InstructionStepView: View {
    let stepNumber: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                
                Text("\(stepNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [URL]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    TemplateShareView(carId: 1, carName: "Mein Auto")
}
