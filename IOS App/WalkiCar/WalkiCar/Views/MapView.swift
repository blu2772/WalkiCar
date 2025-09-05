//
//  MapView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
  @StateObject private var locationManager = LocationManager()
  @StateObject private var mapViewModel = MapViewModel()
  @EnvironmentObject var authManager: AuthManager
  
  @State private var region = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
  )
  
  @State private var showingFriendsOnly = false
  @State private var showingMovingOnly = false
  
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()
      
      VStack {
        // Map
        Map(coordinateRegion: $region, annotationItems: mapViewModel.vehicles) { vehicle in
          MapAnnotation(coordinate: CLLocationCoordinate2D(
            latitude: vehicle.latestPosition?.lat ?? 0,
            longitude: vehicle.latestPosition?.lon ?? 0
          )) {
            VehicleAnnotationView(vehicle: vehicle)
          }
        }
        .onAppear {
          locationManager.requestLocationPermission()
          mapViewModel.loadNearbyVehicles(
            centerLat: region.center.latitude,
            centerLon: region.center.longitude,
            radius: 5000
          )
        }
        .onChange(of: region.center) { newCenter in
          mapViewModel.loadNearbyVehicles(
            centerLat: newCenter.latitude,
            centerLon: newCenter.longitude,
            radius: 5000
          )
        }
        
        // Friends Online Section
        VStack(spacing: 16) {
          HStack {
            Text("Friends Online")
              .font(.headline)
              .foregroundColor(.white)
            
            Spacer()
            
            Text("\(mapViewModel.onlineFriendsCount)")
              .font(.caption)
              .foregroundColor(.green)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.green.opacity(0.2))
              .cornerRadius(12)
          }
          
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(mapViewModel.onlineFriends) { friend in
                FriendOnlineView(friend: friend)
              }
            }
            .padding(.horizontal)
          }
        }
        .padding()
        .background(Color.black.opacity(0.8))
      }
      
      // Filter Controls
      VStack {
        HStack {
          Spacer()
          
          VStack(spacing: 8) {
            FilterButton(
              title: "Friends",
              isActive: showingFriendsOnly,
              action: { showingFriendsOnly.toggle() }
            )
            
            FilterButton(
              title: "Moving",
              isActive: showingMovingOnly,
              action: { showingMovingOnly.toggle() }
            )
          }
          .padding(.trailing)
        }
        .padding(.top)
        
        Spacer()
      }
    }
    .preferredColorScheme(.dark)
  }
}

struct VehicleAnnotationView: View {
  let vehicle: Vehicle
  
  var body: some View {
    VStack {
      Image(systemName: "car.fill")
        .foregroundColor(vehicleColor)
        .font(.title2)
        .background(
          Circle()
            .fill(Color.black.opacity(0.7))
            .frame(width: 30, height: 30)
        )
      
      Text(vehicle.name)
        .font(.caption2)
        .foregroundColor(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
    }
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
}

struct FriendOnlineView: View {
  let friend: User
  
  var body: some View {
    VStack {
      Circle()
        .fill(Color.green)
        .frame(width: 40, height: 40)
        .overlay(
          Text(friend.displayName.prefix(1))
            .font(.headline)
            .foregroundColor(.white)
        )
      
      Text(friend.displayName)
        .font(.caption)
        .foregroundColor(.white)
    }
  }
}

struct FilterButton: View {
  let title: String
  let isActive: Bool
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.caption)
        .foregroundColor(isActive ? .black : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.white : Color.white.opacity(0.3))
        .cornerRadius(12)
    }
  }
}

class MapViewModel: ObservableObject {
  @Published var vehicles: [Vehicle] = []
  @Published var onlineFriends: [User] = []
  @Published var onlineFriendsCount = 0
  
  private let apiService = APIService()
  private var cancellables = Set<AnyCancellable>()
  
  func loadNearbyVehicles(centerLat: Double, centerLon: Double, radius: Int) {
    apiService.getNearbyVehicles(centerLat: centerLat, centerLon: centerLon, radius: radius)
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to load nearby vehicles: \(error)")
          }
        },
        receiveValue: { [weak self] vehicles in
          self?.vehicles = vehicles
        }
      )
      .store(in: &cancellables)
  }
  
  func loadOnlineFriends() {
    apiService.getFriends()
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to load friends: \(error)")
          }
        },
        receiveValue: { [weak self] friendships in
          let friends = friendships.compactMap { $0.friend }
          self?.onlineFriends = friends
          self?.onlineFriendsCount = friends.count
        }
      )
      .store(in: &cancellables)
  }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  @Published var location: CLLocation?
  @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
  
  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
  }
  
  func requestLocationPermission() {
    locationManager.requestWhenInUseAuthorization()
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    self.location = location
  }
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    authorizationStatus = status
    
    if status == .authorizedWhenInUse || status == .authorizedAlways {
      locationManager.startUpdatingLocation()
    }
  }
}

#Preview {
  MapView()
    .environmentObject(AuthManager())
    .environmentObject(AudioRoutingManager())
}
