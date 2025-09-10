//
//  AddCarView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct AddCarView: View {
    @ObservedObject var garageManager: GarageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var year = ""
    @State private var color = ""
    @State private var showingAutomationSetup = false
    @State private var showingTemplateShare = false
    
    private let colors = ["Schwarz", "Weiß", "Grau", "Rot", "Blau", "Grün", "Gelb", "Silber"]
    private let years = Array(1900...Calendar.current.component(.year, from: Date())).reversed()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Fahrzeug hinzufügen")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Erstelle ein neues Fahrzeug für deine Garage")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Form
                        VStack(spacing: 16) {
                            // Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fahrzeugname *")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                TextField("z.B. Mein BMW", text: $name)
                                    .textFieldStyle(CarTextFieldStyle())
                            }
                            
                            // Brand & Model
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Marke")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    TextField("z.B. BMW", text: $brand)
                                        .textFieldStyle(CarTextFieldStyle())
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Modell")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    TextField("z.B. M3", text: $model)
                                        .textFieldStyle(CarTextFieldStyle())
                                }
                            }
                            
                            // Year & Color
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Baujahr")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    TextField("z.B. 2020", text: $year)
                                        .textFieldStyle(CarTextFieldStyle())
                                        .keyboardType(.numberPad)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Farbe")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    TextField("z.B. Schwarz", text: $color)
                                        .textFieldStyle(CarTextFieldStyle())
                                }
                            }
                            
                            // Bluetooth Automatisierung
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bluetooth-Automatisierung")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 12) {
                                    // Template erstellen Button
                                    Button(action: createTemplates) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                                .foregroundColor(.green)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Shortcut-Templates erstellen")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 14, weight: .medium))
                                                
                                                Text("Automatische Shortcuts für Bluetooth-Events")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                    }
                                    
                                    // Automatisierung einrichten Button
                                    Button(action: setupAutomation) {
                                        HStack {
                                            Image(systemName: "gear.badge")
                                                .foregroundColor(.blue)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Automatisierung einrichten")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 14, weight: .medium))
                                                
                                                Text("Manuelle Einrichtung in der Shortcuts-App")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 12))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                    }
                                    
                                    // Info Text
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 12))
                                        
                                        Text("Empfohlen: Erstelle zuerst die Templates, dann richte die Automatisierung ein")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 11))
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Create Button
                        Button(action: createCar) {
                            HStack {
                                if garageManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                Text(garageManager.isLoading ? "Erstelle..." : "Fahrzeug erstellen")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || garageManager.isLoading)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
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
        .sheet(isPresented: $showingAutomationSetup) {
            AutomationSetupView(carName: name)
        }
        .sheet(isPresented: $showingTemplateShare) {
            TemplateShareView(carId: 0, carName: name) // CarId wird nach dem Speichern gesetzt
        }
        .preferredColorScheme(.dark)
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func setupAutomation() {
        showingAutomationSetup = true
    }
    
    private func createTemplates() {
        showingTemplateShare = true
    }
    
    private func createCar() {
        let yearInt = Int(year)
        garageManager.createCar(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: yearInt,
            color: color.isEmpty ? nil : color.trimmingCharacters(in: .whitespacesAndNewlines),
            bluetoothIdentifier: nil // Wird später über Automatisierung gesetzt
        )
        
        dismiss()
    }
}

struct CarTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .foregroundColor(.white)
    }
}

#Preview {
    AddCarView(garageManager: GarageManager())
}
