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
                            
                            CarCardView(car: activeCar, isActive: true)
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
                                        CarCardView(car: car, isActive: car.isActive)
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
        .onAppear {
            garageManager.loadGarage()
        }
    }
}

struct CarCardView: View {
    let car: Car
    let isActive: Bool
    
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
