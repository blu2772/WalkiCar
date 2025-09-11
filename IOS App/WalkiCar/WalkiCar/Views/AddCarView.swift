//
//  AddCarView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct AddCarView: View {
    @ObservedObject var garageManager = GarageManager.shared
    @ObservedObject var audioWatcher: CarAudioWatcher
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var year = ""
    @State private var color = ""
    @State private var selectedAudioDevices: Set<String> = []
    @State private var showingAudioDeviceSelection = false
    
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
                            
                            // Audio Devices
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Audio-Geräte")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Button(action: { showingAudioDeviceSelection = true }) {
                                    HStack {
                                        Image(systemName: "speaker.wave.2")
                                            .foregroundColor(.green)
                                        
                                        if selectedAudioDevices.isEmpty {
                                            Text("Audio-Geräte zuordnen")
                                                .foregroundColor(.gray)
                                        } else {
                                            VStack(alignment: .leading, spacing: 2) {
                                                ForEach(Array(selectedAudioDevices), id: \.self) { deviceName in
                                                    Text(deviceName)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.white)
                                                }
                                            }
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
                                
                                if !selectedAudioDevices.isEmpty {
                                    Text("\(selectedAudioDevices.count) Audio-Gerät(e) ausgewählt")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                        .padding(.top, 4)
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
        .sheet(isPresented: $showingAudioDeviceSelection) {
            AudioDeviceSelectionView(
                audioWatcher: audioWatcher,
                car: Car(
                    id: 0,
                    name: name.isEmpty ? "Neues Auto" : name,
                    brand: brand.isEmpty ? nil : brand,
                    model: model.isEmpty ? nil : model,
                    year: Int(year),
                    color: color.isEmpty ? nil : color,
                    bluetoothIdentifier: nil,
                    audioDeviceNames: Array(selectedAudioDevices),
                    isActive: false,
                    createdAt: nil,
                    updatedAt: nil
                ),
                onDevicesSelected: { devices in
                    selectedAudioDevices = Set(devices)
                }
            )
        }
        .preferredColorScheme(.dark)
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createCar() {
        let yearInt = Int(year)
        garageManager.createCar(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: yearInt,
            color: color.isEmpty ? nil : color.trimmingCharacters(in: .whitespacesAndNewlines),
            bluetoothIdentifier: nil,
            audioDeviceNames: selectedAudioDevices.isEmpty ? nil : Array(selectedAudioDevices)
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
    AddCarView(audioWatcher: CarAudioWatcher.shared)
}
