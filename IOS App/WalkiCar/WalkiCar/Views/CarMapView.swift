import SwiftUI
import MapKit
import CoreLocation

struct CarMapView: View {
    @StateObject private var locationManager = LocationManager.shared
    @ObservedObject private var garageManager = GarageManager.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050), // Berlin
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showingLocationSettings = false
    @State private var showingLocationHistory = false
    @State private var showingCarList = false
    @State private var selectedCar: Car?
    @State private var updateTimer: Timer?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map View
                Map(coordinateRegion: $region, annotationItems: mapAnnotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        VehicleAnnotationView(
                            location: annotation.location,
                            parkedLocation: annotation.parkedLocation,
                            status: annotation.status
                        )
                    }
                }
                .onAppear {
                    setupMap()
                }
                .onChange(of: locationManager.currentLocation) { newLocation in
                    if let location = newLocation {
                        updateRegionToLocation(location)
                    }
                }
                
                // Overlay Controls
                VStack {
                    HStack {
                        Spacer()
                        
                        // Location Permission Button
                        if !locationManager.isLocationEnabled {
                            Button(action: {
                                locationManager.requestLocationPermission()
                            }) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                        
                        // Location Settings Button
                        Button(action: {
                            showingLocationSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        
                        // Car List Button
                        Button(action: {
                            showingCarList = true
                        }) {
                            Image(systemName: "car.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .clipShape(Circle())
                        }
                        
                        // Location History Button
                        Button(action: {
                            showingLocationHistory = true
                        }) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom Status Bar
                    VStack(spacing: 8) {
                        // Tracking Status
                        HStack {
                            Circle()
                                .fill(locationManager.isTracking ? Color.green : Color.gray)
                                .frame(width: 12, height: 12)
                            
                            Text(locationManager.isTracking ? "Live-Tracking aktiv" : "Live-Tracking inaktiv")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(locationManager.liveLocations.count) Live • \(locationManager.parkedLocations.count) Geparkt")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Current Location Info
                        if let currentLocation = locationManager.currentLocation {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                
                                Text("Aktueller Standort: \(String(format: "%.4f", currentLocation.coordinate.latitude)), \(String(format: "%.4f", currentLocation.coordinate.longitude))")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                        }
                        
                        // Error Message
                        if let errorMessage = locationManager.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                }
            }
            .navigationTitle("Live-Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(locationManager.isTracking ? "Stoppen" : "Starten") {
                        if locationManager.isTracking {
                            locationManager.stopLocationTracking()
                        } else {
                            locationManager.startLocationTracking()
                        }
                    }
                    .foregroundColor(locationManager.isTracking ? .red : .green)
                }
            }
        }
        .sheet(isPresented: $showingLocationSettings) {
            LocationSettingsView()
        }
        .sheet(isPresented: $showingLocationHistory) {
            LocationHistoryView(selectedCar: $selectedCar)
        }
        .sheet(isPresented: $showingCarList) {
            CarListView { selectedCar in
                if let coordinate = selectedCar.coordinate {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                }
            }
        }
        .onAppear {
            loadInitialData()
            startPeriodicUpdates()
        }
        .onDisappear {
            stopPeriodicUpdates()
        }
    }
    
    // MARK: - Computed Properties
    
    private var mapAnnotations: [MapAnnotationData] {
        var annotations: [MapAnnotationData] = []
        
        // Live Locations
        for location in locationManager.liveLocations {
            annotations.append(MapAnnotationData(
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                location: location,
                parkedLocation: nil,
                status: locationManager.getLocationStatus(for: location)
            ))
        }
        
        // Parked Locations
        for parkedLocation in locationManager.parkedLocations {
            annotations.append(MapAnnotationData(
                coordinate: CLLocationCoordinate2D(latitude: parkedLocation.latitude, longitude: parkedLocation.longitude),
                location: nil,
                parkedLocation: parkedLocation,
                status: locationManager.getLocationStatus(for: parkedLocation)
            ))
        }
        
        return annotations
    }
    
    // MARK: - Private Methods
    
    private func setupMap() {
        if let currentLocation = locationManager.currentLocation {
            updateRegionToLocation(currentLocation)
        }
    }
    
    private func updateRegionToLocation(_ location: CLLocation) {
        withAnimation(.easeInOut(duration: 1.0)) {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func loadInitialData() {
        locationManager.fetchLiveLocations()
        garageManager.loadGarage()
        garageManager.loadCarsWithLocations()
    }
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            locationManager.fetchLiveLocations()
        }
    }
    
    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

// MARK: - Map Annotation Data

struct MapAnnotationData: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let location: Location?
    let parkedLocation: ParkedLocation?
    let status: LocationStatus
}

// MARK: - Vehicle Annotation View

struct VehicleAnnotationView: View {
    let location: Location?
    let parkedLocation: ParkedLocation?
    let status: LocationStatus
    
    var body: some View {
        VStack(spacing: 4) {
            // Vehicle Icon
            Image(systemName: vehicleIcon)
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(statusColor)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Status Badge
            Text(status.displayName)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor)
                .clipShape(Capsule())
        }
    }
    
    private var vehicleIcon: String {
        if let car = location?.carName ?? parkedLocation?.carName {
            if car.lowercased().contains("bmw") {
                return "car.fill"
            } else if car.lowercased().contains("audi") {
                return "car.fill"
            } else {
                return "car.fill"
            }
        }
        return "car.fill"
    }
    
    private var statusColor: Color {
        switch status {
        case .live:
            return .green
        case .parked:
            return .orange
        case .offline:
            return .gray
        }
    }
}

// MARK: - Location Settings View

struct LocationSettingsView: View {
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var settings: [LocationSetting] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView("Lade Einstellungen...")
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(settings) { setting in
                        LocationSettingRow(setting: setting)
                    }
                }
            }
            .navigationTitle("Standort-Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        Task {
            do {
                let response = try await locationManager.fetchLocationSettings()
                await MainActor.run {
                    self.settings = response.settings
                    self.isLoading = false
                }
            } catch {
                print("❌ Fehler beim Laden der Standort-Einstellungen: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Location Setting Row

struct LocationSettingRow: View {
    let setting: LocationSetting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(setting.carName ?? "Alle Fahrzeuge")
                    .font(.headline)
                
                Spacer()
                
                Text(setting.visibility.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            HStack {
                Label("Standort teilen", systemImage: setting.shareLocation ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(setting.shareLocation ? .green : .red)
                
                Spacer()
                
                if setting.shareLocation {
                    Label("Bewegung", systemImage: setting.shareWhenMoving ? "checkmark" : "xmark")
                        .font(.caption)
                        .foregroundColor(setting.shareWhenMoving ? .green : .red)
                    
                    Label("Stehend", systemImage: setting.shareWhenStationary ? "checkmark" : "xmark")
                        .font(.caption)
                        .foregroundColor(setting.shareWhenStationary ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Location History View

struct LocationHistoryView: View {
    @ObservedObject private var garageManager = GarageManager.shared
    @Binding var selectedCar: Car?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(garageManager.cars) { car in
                    Button(action: {
                        selectedCar = car
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(car.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let brand = car.brand, let model = car.model {
                                    Text("\(brand) \(model)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Fahrzeug auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            garageManager.loadGarage()
        }
    }
}

// MARK: - Car List View

struct CarListView: View {
    @ObservedObject private var garageManager = GarageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCar: CarWithLocation?
    let onCarSelected: ((CarWithLocation) -> Void)?
    
    init(onCarSelected: ((CarWithLocation) -> Void)? = nil) {
        self.onCarSelected = onCarSelected
    }
    
    var body: some View {
        NavigationView {
            List {
                if garageManager.isLoading {
                    ProgressView("Lade Autos...")
                        .frame(maxWidth: .infinity)
                } else if garageManager.carsWithLocations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("Keine Autos gefunden")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Füge dein erstes Auto in der Garage hinzu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(garageManager.carsWithLocations) { car in
                        CarListRow(car: car) {
                            selectedCar = car
                            onCarSelected?(car)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Meine Autos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            garageManager.loadCarsWithLocations()
        }
    }
}

// MARK: - Car List Row

struct CarListRow: View {
    let car: CarWithLocation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                // Car Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(car.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(car.statusText)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .clipShape(Capsule())
                        
                        if car.hasLocation {
                            Text("📍 Standort verfügbar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("❌ Kein Standort")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let year = car.year {
                        Text("Baujahr: \(year)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch car.status {
        case "live":
            return .green
        case "parked":
            return .orange
        case "offline":
            return .gray
        default:
            return .gray
        }
    }
}

#Preview {
    CarMapView()
}