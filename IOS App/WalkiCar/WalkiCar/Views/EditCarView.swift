//
//  EditCarView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct EditCarView: View {
    @ObservedObject var garageManager = GarageManager.shared
    @ObservedObject var audioWatcher: CarAudioWatcher
    let car: Car
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var brand: String
    @State private var model: String
    @State private var year: Int
    @State private var color: String
    @State private var audioDeviceNames: [String]
    
    @State private var showingAudioDeviceSelection = false
    @State private var showingDeleteConfirmation = false
    
    init(car: Car) {
        self.car = car
        self.audioWatcher = CarAudioWatcher.shared
        
        // Initialisiere State mit aktuellen Werten
        self._name = State(initialValue: car.name)
        self._brand = State(initialValue: car.brand ?? "")
        self._model = State(initialValue: car.model ?? "")
        self._year = State(initialValue: car.year ?? Calendar.current.component(.year, from: Date()))
        self._color = State(initialValue: car.color ?? "")
        self._audioDeviceNames = State(initialValue: car.audioDeviceNames ?? [])
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Fahrzeug bearbeiten")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Aktualisiere die Informationen deines Fahrzeugs")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fahrzeugname *")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                TextField("z.B. Mein Auto", text: $name)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // Brand & Model
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Marke")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    TextField("z.B. BMW", text: $brand)
                                        .textFieldStyle(CustomTextFieldStyle())
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Modell")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    TextField("z.B. X5", text: $model)
                                        .textFieldStyle(CustomTextFieldStyle())
                                }
                            }
                            
                            // Year & Color
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Baujahr")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Picker("Baujahr", selection: $year) {
                                        ForEach(Array(1900...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                                            Text("\(year)").tag(year)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Farbe")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    TextField("z.B. Schwarz", text: $color)
                                        .textFieldStyle(CustomTextFieldStyle())
                                }
                            }
                            
                            // Audio Devices
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Audio-Geräte")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Button(action: { showingAudioDeviceSelection = true }) {
                                    HStack {
                                        if audioDeviceNames.isEmpty {
                                            Text("Audio-Geräte zuordnen")
                                                .foregroundColor(.gray)
                                        } else {
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(audioDeviceNames, id: \.self) { deviceName in
                                                    Text(deviceName)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "speaker.wave.2")
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                if !audioDeviceNames.isEmpty {
                                    Text("\(audioDeviceNames.count) Audio-Gerät(e) zugeordnet")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            // Save Button
                            Button(action: saveCar) {
                                HStack {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("Änderungen speichern")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color.blue : Color.gray)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || garageManager.isLoading)
                            
                            // Delete Button
                            Button(action: { showingDeleteConfirmation = true }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("Fahrzeug löschen")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                            .disabled(garageManager.isLoading)
                        }
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
                car: car,
                onDevicesSelected: { devices in
                    audioDeviceNames = devices
                }
            )
        }
        .alert("Fahrzeug löschen", isPresented: $showingDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                deleteCar()
            }
        } message: {
            Text("Möchtest du dieses Fahrzeug wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .preferredColorScheme(.dark)
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveCar() {
        garageManager.updateCar(
            carId: car.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year,
            color: color.isEmpty ? nil : color.trimmingCharacters(in: .whitespacesAndNewlines),
            bluetoothIdentifier: nil,
            audioDeviceNames: audioDeviceNames.isEmpty ? nil : audioDeviceNames
        )
        
        dismiss()
    }
    
    private func deleteCar() {
        garageManager.deleteCar(carId: car.id)
        dismiss()
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .foregroundColor(.white)
    }
}

#Preview {
    EditCarView(car: Car(
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
    ))
}
