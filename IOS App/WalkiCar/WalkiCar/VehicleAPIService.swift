// MARK: - API Service Extensions for Vehicles

import Foundation
extension APIService {
  func getUserVehicles() async throws -> [Vehicle] {
    guard let url = URL(string: "\(baseURL)/vehicles/mine") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add JWT token here
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
    
    return try JSONDecoder().decode([Vehicle].self, from: data)
  }
  
  func createVehicle(name: String, brand: String?, model: String?, color: String?, visibility: String, trackMode: String) async throws -> Vehicle {
    guard let url = URL(string: "\(baseURL)/vehicles") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestBody: [String: Any?] = [
      "name": name,
      "brand": brand,
      "model": model,
      "color": color,
      "visibility": visibility,
      "track_mode": trackMode
    ]
    
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody.compactMapValues { $0 })
    // Add JWT token here
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 201 else {
      throw APIError.invalidResponse
    }
    
    return try JSONDecoder().decode(Vehicle.self, from: data)
  }
  
  func updateVehicle(id: Int, name: String?, brand: String?, model: String?, color: String?, visibility: String?, trackMode: String?) async throws -> Vehicle {
    guard let url = URL(string: "\(baseURL)/vehicles/\(id)") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "PATCH"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestBody: [String: Any?] = [
      "name": name,
      "brand": brand,
      "model": model,
      "color": color,
      "visibility": visibility,
      "track_mode": trackMode
    ]
    
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody.compactMapValues { $0 })
    // Add JWT token here
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
    
    return try JSONDecoder().decode(Vehicle.self, from: data)
  }
  
  func deleteVehicle(id: Int) async throws {
    guard let url = URL(string: "\(baseURL)/vehicles/\(id)") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "DELETE"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add JWT token here
    
    let (_, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
  }
  
  func sendVehiclePosition(vehicleId: Int, lat: Double, lon: Double, speed: Double?, heading: Double?, moving: Bool) async throws {
    guard let url = URL(string: "\(baseURL)/vehicles/\(vehicleId)/positions") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestBody: [String: Any?] = [
      "lat": lat,
      "lon": lon,
      "speed": speed,
      "heading": heading,
      "moving": moving
    ]
    
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody.compactMapValues { $0 })
    // Add JWT token here
    
    let (_, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 201 else {
      throw APIError.invalidResponse
    }
  }
  
  func getNearbyVehicles(centerLat: Double, centerLon: Double, radius: Double = 5000) async throws -> [NearbyVehicle] {
    guard let url = URL(string: "\(baseURL)/map/nearby?centerLat=\(centerLat)&centerLon=\(centerLon)&radius=\(radius)") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add JWT token here
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
    
    return try JSONDecoder().decode([NearbyVehicle].self, from: data)
  }
  
  func getVehiclePositions(vehicleId: Int, limit: Int = 100) async throws -> [VehiclePosition] {
    guard let url = URL(string: "\(baseURL)/vehicles/\(vehicleId)/positions?limit=\(limit)") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add JWT token here
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
    
    return try JSONDecoder().decode([VehiclePosition].self, from: data)
  }
}
