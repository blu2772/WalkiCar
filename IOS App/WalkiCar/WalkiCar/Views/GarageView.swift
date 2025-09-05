//
//  GarageView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct GarageView: View {
  @StateObject private var garageViewModel = GarageViewModel()
  @State private var showingAddVehicle = false
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black
          .ignoresSafeArea()
        
        VStack {
          if garageViewModel.vehicles.isEmpty {
            EmptyGarageView()
          } else {
            ScrollView {
              LazyVStack(spacing: 16) {
                ForEach(garageViewModel.vehicles) { vehicle in
                  VehicleCardView(vehicle: vehicle)
                }
              }
              .padding()
            }
          }
          
          Spacer()
          
          Button(action: { showingAddVehicle = true }) {
            Image(systemName: "plus")
              .font(.title2)
              .foregroundColor(.white)
              .frame(width: 56, height: 56)
              .background(Color.blue)
              .clipShape(Circle())
          }
          .padding(.bottom, 20)
        }
      }
      .navigationTitle("Garage")
      .navigationBarTitleDisplayMode(.large)
      .preferredColorScheme(.dark)
      .sheet(isPresented: $showingAddVehicle) {
        AddVehicleView { vehicleData in
          garageViewModel.addVehicle(vehicleData)
        }
      }
    }
    .onAppear {
      garageViewModel.loadVehicles()
    }
  }
}

struct VehicleCardView: View {
  let vehicle: Vehicle
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        // Vehicle Image Placeholder
        RoundedRectangle(cornerRadius: 8)
          .fill(vehicleColor)
          .frame(width: 80, height: 60)
          .overlay(
            Image(systemName: "car.fill")
              .foregroundColor(.white)
              .font(.title2)
          )
        
        VStack(alignment: .leading, spacing: 4) {
          Text(vehicle.name)
            .font(.headline)
            .foregroundColor(.white)
          
          if let brand = vehicle.brand, let model = vehicle.model {
            Text("\(brand) \(model)")
              .font(.caption)
              .foregroundColor(.gray)
          }
          
          HStack {
            Text(visibilityText)
              .font(.caption2)
              .foregroundColor(.blue)
            
            Spacer()
            
            Text(trackingText)
              .font(.caption2)
              .foregroundColor(.green)
          }
        }
        
        Spacer()
        
        VStack {
          Text("\(vehicle.latestPosition?.moving == true ? "🟢" : "🔴")")
            .font(.title2)
          
          Text("\(vehicle.latestPosition?.speed ?? 0, specifier: "%.0f") km/h")
            .font(.caption2)
            .foregroundColor(.gray)
        }
      }
      
      HStack {
        Button(action: {}) {
          Text("Edit")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(16)
        }
        
        Spacer()
        
        Button(action: {}) {
          Text("Track")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green)
            .cornerRadius(16)
        }
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
  
  private var vehicleColor: Color {
    switch vehicle.color?.lowercased() {
    case "red": return .red
    case "blue": return .blue
    case "green": return .green
    case "yellow": return .yellow
    case "white": return .white
    case "black": return .black
    default: return .gray
    }
  }
  
  private var visibilityText: String {
    switch vehicle.visibility {
    case "private": return "Visibility: Private"
    case "friends": return "Visibility: Friends"
    case "public": return "Visibility: Public"
    default: return "Visibility: Private"
    }
  }
  
  private var trackingText: String {
    switch vehicle.trackMode {
    case "off": return "Tracking: Off"
    case "moving_only": return "Tracking: Moving Only"
    case "always": return "Tracking: Always"
    default: return "Tracking: Off"
    }
  }
}

struct EmptyGarageView: View {
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "car")
        .font(.system(size: 60))
        .foregroundColor(.gray)
      
      Text("No Vehicles Yet")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
      
      Text("Add your first vehicle to start tracking and sharing your location with friends")
        .font(.body)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct AddVehicleView: View {
  @Environment(\.dismiss) private var dismiss
  let onAdd: (VehicleData) -> Void
  
  @State private var name = ""
  @State private var brand = ""
  @State private var model = ""
  @State private var color = "gray"
  @State private var visibility = "private"
  @State private var trackMode = "off"
  
  private let colors = ["red", "blue", "green", "yellow", "white", "black", "gray"]
  private let visibilities = ["private", "friends", "public"]
  private let trackModes = ["off", "moving_only", "always"]
  
  var body: some View {
    NavigationView {
      Form {
        Section("Vehicle Details") {
          TextField("Vehicle Name", text: $name)
          TextField("Brand", text: $brand)
          TextField("Model", text: $model)
          
          Picker("Color", selection: $color) {
            ForEach(colors, id: \.self) { color in
              Text(color.capitalized).tag(color)
            }
          }
        }
        
        Section("Privacy & Tracking") {
          Picker("Visibility", selection: $visibility) {
            Text("Private").tag("private")
            Text("Friends").tag("friends")
            Text("Public").tag("public")
          }
          
          Picker("Tracking Mode", selection: $trackMode) {
            Text("Off").tag("off")
            Text("Moving Only").tag("moving_only")
            Text("Always").tag("always")
          }
        }
      }
      .navigationTitle("Add Vehicle")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Add") {
            let vehicleData = VehicleData(
              name: name,
              brand: brand.isEmpty ? nil : brand,
              model: model.isEmpty ? nil : model,
              color: color,
              visibility: visibility,
              trackMode: trackMode
            )
            onAdd(vehicleData)
            dismiss()
          }
          .disabled(name.isEmpty)
        }
      }
    }
  }
}

struct VehicleData {
  let name: String
  let brand: String?
  let model: String?
  let color: String
  let visibility: String
  let trackMode: String
}

class GarageViewModel: ObservableObject {
  @Published var vehicles: [Vehicle] = []
  
  private let apiService = APIService()
  private var cancellables = Set<AnyCancellable>()
  
  func loadVehicles() {
    apiService.getVehicles()
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to load vehicles: \(error)")
          }
        },
        receiveValue: { [weak self] vehicles in
          self?.vehicles = vehicles
        }
      )
      .store(in: &cancellables)
  }
  
  func addVehicle(_ vehicleData: VehicleData) {
    apiService.createVehicle(
      name: vehicleData.name,
      brand: vehicleData.brand,
      model: vehicleData.model,
      color: vehicleData.color,
      visibility: vehicleData.visibility,
      trackMode: vehicleData.trackMode
    )
    .sink(
      receiveCompletion: { completion in
        if case .failure(let error) = completion {
          print("Failed to create vehicle: \(error)")
        }
      },
      receiveValue: { [weak self] _ in
        self?.loadVehicles()
      }
    )
    .store(in: &cancellables)
  }
}

#Preview {
  GarageView()
    .environmentObject(AuthManager())
    .environmentObject(AudioRoutingManager())
}
