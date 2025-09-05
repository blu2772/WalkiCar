import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Vehicle Data Models
struct Vehicle: Codable, Identifiable {
  let id: Int
  let name: String
  let brand: String?
  let model: String?
  let color: String?
  let ble_identifier: String?
  let visibility: String
  let track_mode: String
  let created_at: String
}

struct VehiclePosition: Codable, Identifiable {
  let id: Int
  let vehicle_id: Int
  let lat: Double
  let lon: Double
  let speed: Double?
  let heading: Double?
  let moving: Bool
  let ts: String
}

struct NearbyVehicle: Codable, Identifiable {
  let id: Int
  let name: String
  let brand: String?
  let model: String?
  let color: String?
  let visibility: String
  let track_mode: String
  let lat: Double
  let lon: Double
  let speed: Double?
  let moving: Bool
}

// MARK: - Vehicle Service
class VehicleService: ObservableObject {
  @Published var vehicles: [Vehicle] = []
  @Published var nearbyVehicles: [NearbyVehicle] = []
  @Published var isLoading = false
  
  private let apiService = APIService()
  private let locationManager = CLLocationManager()
  @Published var currentLocation: CLLocation?
  
  init() {
    setupLocationManager()
  }
  
  private func setupLocationManager() {
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.requestWhenInUseAuthorization()
  }
  
  func loadVehicles() async {
    isLoading = true
    do {
      let vehicles = try await apiService.getUserVehicles()
      await MainActor.run {
        self.vehicles = vehicles
        self.isLoading = false
      }
    } catch {
      print("❌ Failed to load vehicles: \(error)")
      await MainActor.run {
        self.isLoading = false
      }
    }
  }
  
  func createVehicle(name: String, brand: String?, model: String?, color: String?, visibility: String, trackMode: String) async {
    do {
      let vehicle = try await apiService.createVehicle(
        name: name,
        brand: brand,
        model: model,
        color: color,
        visibility: visibility,
        trackMode: trackMode
      )
      await MainActor.run {
        self.vehicles.append(vehicle)
      }
    } catch {
      print("❌ Failed to create vehicle: \(error)")
    }
  }
  
  func updateVehicle(id: Int, name: String?, brand: String?, model: String?, color: String?, visibility: String?, trackMode: String?) async {
    do {
      let updatedVehicle = try await apiService.updateVehicle(
        id: id,
        name: name,
        brand: brand,
        model: model,
        color: color,
        visibility: visibility,
        trackMode: trackMode
      )
      await MainActor.run {
        if let index = self.vehicles.firstIndex(where: { $0.id == id }) {
          self.vehicles[index] = updatedVehicle
        }
      }
    } catch {
      print("❌ Failed to update vehicle: \(error)")
    }
  }
  
  func deleteVehicle(id: Int) async {
    do {
      try await apiService.deleteVehicle(id: id)
      await MainActor.run {
        self.vehicles.removeAll { $0.id == id }
      }
    } catch {
      print("❌ Failed to delete vehicle: \(error)")
    }
  }
  
  func sendPosition(vehicleId: Int, lat: Double, lon: Double, speed: Double?, heading: Double?, moving: Bool) async {
    do {
      try await apiService.sendVehiclePosition(
        vehicleId: vehicleId,
        lat: lat,
        lon: lon,
        speed: speed,
        heading: heading,
        moving: moving
      )
    } catch {
      print("❌ Failed to send position: \(error)")
    }
  }
  
  func loadNearbyVehicles(centerLat: Double, centerLon: Double, radius: Double = 5000) async {
    do {
      let vehicles = try await apiService.getNearbyVehicles(
        centerLat: centerLat,
        centerLon: centerLon,
        radius: radius
      )
      await MainActor.run {
        self.nearbyVehicles = vehicles
      }
    } catch {
      print("❌ Failed to load nearby vehicles: \(error)")
    }
  }
}

// MARK: - Location Manager Delegate
extension VehicleService: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    currentLocation = location
    
    // Auto-update nearby vehicles when location changes
    Task {
      await loadNearbyVehicles(
        centerLat: location.coordinate.latitude,
        centerLon: location.coordinate.longitude
      )
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("❌ Location manager error: \(error)")
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      locationManager.startUpdatingLocation()
    case .denied, .restricted:
      print("❌ Location access denied")
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    @unknown default:
      break
    }
  }
}

// MARK: - Enhanced Map View
struct MapView: View {
  @StateObject private var vehicleService = VehicleService()
  @State private var region = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
  )
  @State private var showingAddVehicle = false
  @State private var selectedVehicle: Vehicle?
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Map
          Map(coordinateRegion: $region, annotationItems: vehicleService.nearbyVehicles) { vehicle in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lon)) {
              VehicleAnnotation(vehicle: vehicle)
            }
          }
          .frame(height: 400)
          .onAppear {
            if let location = vehicleService.currentLocation {
              region.center = location.coordinate
            }
          }
          
          // Friends Online Section
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Text("Friends Online")
                .font(.headline)
                .foregroundColor(.white)
              
              Spacer()
              
              Text("\(vehicleService.nearbyVehicles.count)")
                .font(.caption)
                .foregroundColor(.green)
                .padding(8)
                .background(Color.green.opacity(0.2))
                .clipShape(Circle())
            }
            
            // Nearby vehicles list
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                ForEach(vehicleService.nearbyVehicles) { vehicle in
                  NearbyVehicleCard(vehicle: vehicle)
                }
              }
              .padding(.horizontal)
            }
          }
          .padding()
          
          Spacer()
        }
      }
      .navigationTitle("Map")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Add Vehicle") {
            showingAddVehicle = true
          }
          .foregroundColor(.blue)
        }
      }
      .sheet(isPresented: $showingAddVehicle) {
        AddVehicleView(vehicleService: vehicleService)
      }
      .onAppear {
        Task {
          await vehicleService.loadVehicles()
        }
      }
    }
  }
}

// MARK: - Vehicle Annotation
struct VehicleAnnotation: View {
  let vehicle: NearbyVehicle
  
  var body: some View {
    VStack(spacing: 4) {
      ZStack {
        Circle()
          .fill(vehicle.moving ? .green : .gray)
          .frame(width: 20, height: 20)
        
        Image(systemName: "car.fill")
          .font(.system(size: 10))
          .foregroundColor(.white)
      }
      
      Text(vehicle.name)
        .font(.caption2)
        .foregroundColor(.white)
        .padding(4)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
    }
  }
}

// MARK: - Nearby Vehicle Card
struct NearbyVehicleCard: View {
  let vehicle: NearbyVehicle
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Circle()
          .fill(vehicle.moving ? .green : .gray)
          .frame(width: 8, height: 8)
        
        Text(vehicle.name)
          .font(.headline)
          .foregroundColor(.white)
        
        Spacer()
      }
      
      if let brand = vehicle.brand, let model = vehicle.model {
        Text("\(brand) \(model)")
          .font(.caption)
          .foregroundColor(.gray)
      }
      
      if let speed = vehicle.speed {
        Text("\(Int(speed)) km/h")
          .font(.caption)
          .foregroundColor(.green)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
    .frame(width: 150)
  }
}

// MARK: - Enhanced Garage View
struct GarageView: View {
  @StateObject private var vehicleService = VehicleService()
  @State private var showingAddVehicle = false
  @State private var selectedVehicle: Vehicle?
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        if vehicleService.isLoading {
          ProgressView("Loading vehicles...")
            .foregroundColor(.white)
        } else {
          ScrollView {
            LazyVStack(spacing: 16) {
              ForEach(vehicleService.vehicles) { vehicle in
                VehicleCard(
                  vehicle: vehicle,
                  onEdit: { selectedVehicle = vehicle },
                  onDelete: { vehicleId in
                    Task {
                      await vehicleService.deleteVehicle(id: vehicleId)
                    }
                  }
                )
              }
              
              if vehicleService.vehicles.isEmpty {
                VStack(spacing: 16) {
                  Image(systemName: "car")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                  
                  Text("No vehicles in garage")
                    .font(.headline)
                    .foregroundColor(.white)
                  
                  Text("Add your first vehicle to start tracking")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                }
                .padding()
              }
            }
            .padding()
          }
        }
      }
      .navigationTitle("Garage")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Add") {
            showingAddVehicle = true
          }
          .foregroundColor(.blue)
        }
      }
      .sheet(isPresented: $showingAddVehicle) {
        AddVehicleView(vehicleService: vehicleService)
      }
      .sheet(item: $selectedVehicle) { vehicle in
        EditVehicleView(vehicle: vehicle, vehicleService: vehicleService)
      }
      .onAppear {
        Task {
          await vehicleService.loadVehicles()
        }
      }
    }
  }
}

// MARK: - Enhanced Vehicle Card
struct VehicleCard: View {
  let vehicle: Vehicle
  let onEdit: () -> Void
  let onDelete: (Int) -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        // Vehicle image placeholder
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: 80, height: 60)
          .cornerRadius(8)
        
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(vehicle.name)
              .font(.headline)
              .foregroundColor(.white)
            
            Spacer()
            
            // Visibility indicator
            HStack(spacing: 4) {
              Image(systemName: visibilityIcon(vehicle.visibility))
                .foregroundColor(visibilityColor(vehicle.visibility))
                .font(.caption)
              
              Text(vehicle.visibility.capitalized)
                .font(.caption)
                .foregroundColor(visibilityColor(vehicle.visibility))
            }
          }
          
          if let brand = vehicle.brand, let model = vehicle.model {
            Text("\(brand) \(model)")
              .font(.subheadline)
              .foregroundColor(.gray)
          }
          
          Text("Visibility: \(vehicle.visibility.capitalized)")
            .font(.caption)
            .foregroundColor(.gray)
          
          Text("Tracking: \(vehicle.track_mode.replacingOccurrences(of: "_", with: " ").capitalized)")
            .font(.caption)
            .foregroundColor(.gray)
        }
      }
      
      // Action buttons
      HStack(spacing: 12) {
        Button("Edit") {
          onEdit()
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
        
        Button("Delete") {
          onDelete(vehicle.id)
        }
        .foregroundColor(.red)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.2))
        .cornerRadius(8)
        
        Spacer()
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
  
  private func visibilityIcon(_ visibility: String) -> String {
    switch visibility {
    case "public": return "globe"
    case "friends": return "person.2"
    case "private": return "lock"
    default: return "questionmark"
    }
  }
  
  private func visibilityColor(_ visibility: String) -> Color {
    switch visibility {
    case "public": return .green
    case "friends": return .blue
    case "private": return .red
    default: return .gray
    }
  }
}

// MARK: - Add Vehicle View
struct AddVehicleView: View {
  @ObservedObject var vehicleService: VehicleService
  @Environment(\.dismiss) private var dismiss
  
  @State private var name = ""
  @State private var brand = ""
  @State private var model = ""
  @State private var color = ""
  @State private var visibility = "private"
  @State private var trackMode = "off"
  
  let visibilityOptions = ["private", "friends", "public"]
  let trackModeOptions = ["off", "moving_only", "always"]
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        Form {
          Section("Vehicle Details") {
            TextField("Name", text: $name)
            TextField("Brand (optional)", text: $brand)
            TextField("Model (optional)", text: $model)
            TextField("Color (optional)", text: $color)
          }
          
          Section("Privacy Settings") {
            Picker("Visibility", selection: $visibility) {
              ForEach(visibilityOptions, id: \.self) { option in
                Text(option.capitalized).tag(option)
              }
            }
            
            Picker("Tracking Mode", selection: $trackMode) {
              ForEach(trackModeOptions, id: \.self) { option in
                Text(option.replacingOccurrences(of: "_", with: " ").capitalized).tag(option)
              }
            }
          }
        }
        .scrollContentBackground(.hidden)
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
          Button("Save") {
            Task {
              await vehicleService.createVehicle(
                name: name,
                brand: brand.isEmpty ? nil : brand,
                model: model.isEmpty ? nil : model,
                color: color.isEmpty ? nil : color,
                visibility: visibility,
                trackMode: trackMode
              )
              dismiss()
            }
          }
          .disabled(name.isEmpty)
        }
      }
    }
  }
}

// MARK: - Edit Vehicle View
struct EditVehicleView: View {
  let vehicle: Vehicle
  @ObservedObject var vehicleService: VehicleService
  @Environment(\.dismiss) private var dismiss
  
  @State private var name: String
  @State private var brand: String
  @State private var model: String
  @State private var color: String
  @State private var visibility: String
  @State private var trackMode: String
  
  let visibilityOptions = ["private", "friends", "public"]
  let trackModeOptions = ["off", "moving_only", "always"]
  
  init(vehicle: Vehicle, vehicleService: VehicleService) {
    self.vehicle = vehicle
    self.vehicleService = vehicleService
    self._name = State(initialValue: vehicle.name)
    self._brand = State(initialValue: vehicle.brand ?? "")
    self._model = State(initialValue: vehicle.model ?? "")
    self._color = State(initialValue: vehicle.color ?? "")
    self._visibility = State(initialValue: vehicle.visibility)
    self._trackMode = State(initialValue: vehicle.track_mode)
  }
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        Form {
          Section("Vehicle Details") {
            TextField("Name", text: $name)
            TextField("Brand", text: $brand)
            TextField("Model", text: $model)
            TextField("Color", text: $color)
          }
          
          Section("Privacy Settings") {
            Picker("Visibility", selection: $visibility) {
              ForEach(visibilityOptions, id: \.self) { option in
                Text(option.capitalized).tag(option)
              }
            }
            
            Picker("Tracking Mode", selection: $trackMode) {
              ForEach(trackModeOptions, id: \.self) { option in
                Text(option.replacingOccurrences(of: "_", with: " ").capitalized).tag(option)
              }
            }
          }
        }
        .scrollContentBackground(.hidden)
      }
      .navigationTitle("Edit Vehicle")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            Task {
              await vehicleService.updateVehicle(
                id: vehicle.id,
                name: name,
                brand: brand.isEmpty ? nil : brand,
                model: model.isEmpty ? nil : model,
                color: color.isEmpty ? nil : color,
                visibility: visibility,
                trackMode: trackMode
              )
              dismiss()
            }
          }
        }
      }
    }
  }
}
