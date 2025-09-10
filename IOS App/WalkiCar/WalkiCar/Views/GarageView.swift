//
//  GarageView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct GarageView: View {
    @StateObject private var garageManager = GarageManager()
    @State private var showingAddCar = false
    @State private var showingBluetoothScan = false
    @State private var showingEditCar: Car? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Garage")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { showingAddCar = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Active Car Section
                    if let activeCar = garageManager.activeCar {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Aktives Fahrzeug")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                            
                            CarCardView(
                                car: activeCar, 
                                isActive: true,
                                onEdit: { showingEditCar = activeCar },
                                onDelete: { deleteCar(activeCar) },
                                onSetActive: { setActiveCar(activeCar) }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                    }
                    
                    // Cars list
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Alle Fahrzeuge")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(garageManager.cars.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        if garageManager.isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Lade Fahrzeuge...")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                        } else if garageManager.cars.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Keine Fahrzeuge")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Füge dein erstes Fahrzeug hinzu")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 50)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(garageManager.cars) { car in
                                        CarCardView(
                                            car: car, 
                                            isActive: car.isActive,
                                            onEdit: { showingEditCar = car },
                                            onDelete: { deleteCar(car) },
                                            onSetActive: { setActiveCar(car) }
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
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddCar) {
            AddCarView(garageManager: garageManager)
        }
        .sheet(isPresented: $showingBluetoothScan) {
            BluetoothScanView(garageManager: garageManager)
        }
        .sheet(item: $showingEditCar) { car in
            EditCarView(garageManager: garageManager, car: car)
        }
        .onAppear {
            garageManager.loadGarage()
        }
    }
    
    private func deleteCar(_ car: Car) {
        garageManager.deleteCar(carId: car.id)
    }
    
    private func setActiveCar(_ car: Car) {
        garageManager.setActiveCar(carId: car.id)
    }
}

struct CarCardView: View {
    let car: Car
    let isActive: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetActive: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.system(size: 40))
                    .foregroundColor(carColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(car.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let brand = car.brand, let model = car.model {
                        Text("\(brand) \(model)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    if let year = car.year {
                        Text("\(year)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    if let bluetoothId = car.bluetoothIdentifier {
                        Text("🔵 \(bluetoothId)")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    // Status
                    VStack(spacing: 4) {
                        if isActive {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(isActive ? "Aktiv" : "Inaktiv")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isActive ? .green : .gray)
                    }
                    
                    // Action Buttons
                    HStack(spacing: 8) {
                        // Set Active Button
                        if !isActive {
                            Button(action: onSetActive) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Edit Button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        
                        // Delete Button
                        Button(action: { showingDeleteConfirmation = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .alert("Fahrzeug löschen", isPresented: $showingDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Möchtest du '\(car.name)' wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
    
    private var carColor: Color {
        switch car.color?.lowercased() {
        case "rot", "red":
            return .red
        case "blau", "blue":
            return .blue
        case "grün", "green":
            return .green
        case "gelb", "yellow":
            return .yellow
        case "schwarz", "black":
            return .black
        case "weiß", "white":
            return .white
        case "grau", "gray", "grey":
            return .gray
        default:
            return .gray
        }
    }
}

#Preview {
    GarageView()
}

#Preview("CarCardView") {
    CarCardView(
        car: Car(
            id: 1,
            name: "Mein Auto",
            brand: "BMW",
            model: "X5",
            year: 2020,
            color: "Schwarz",
            bluetoothIdentifier: "ABC123",
            isActive: false,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z"
        ),
        isActive: false,
        onEdit: {},
        onDelete: {},
        onSetActive: {}
    )
    .padding()
    .background(Color.black)
}
