//
//  Car.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation
import CoreLocation

struct Car: Codable, Identifiable {
    let id: Int
    let name: String
    let brand: String?
    let model: String?
    let year: Int?
    let color: String?
    let bluetoothIdentifier: String?
    let audioDeviceNames: [String]?
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case model
        case year
        case color
        case bluetoothIdentifier = "bluetooth_identifier"
        case audioDeviceNames = "audio_device_names"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Manual initializer
    init(id: Int, name: String, brand: String?, model: String?, year: Int?, color: String?, bluetoothIdentifier: String?, audioDeviceNames: [String]?, isActive: Bool, createdAt: String?, updatedAt: String?) {
        self.id = id
        self.name = name
        self.brand = brand
        self.model = model
        self.year = year
        self.color = color
        self.bluetoothIdentifier = bluetoothIdentifier
        self.audioDeviceNames = audioDeviceNames
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom initializer für flexible is_active Dekodierung
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        bluetoothIdentifier = try container.decodeIfPresent(String.self, forKey: .bluetoothIdentifier)
        
        // Flexible audio_device_names Dekodierung (Array oder JSON-String)
        if let arrayValue = try? container.decode([String].self, forKey: .audioDeviceNames) {
            audioDeviceNames = arrayValue
        } else if let stringValue = try? container.decode(String.self, forKey: .audioDeviceNames) {
            // Versuche JSON-String zu parsen
            if let data = stringValue.data(using: .utf8),
               let parsedArray = try? JSONDecoder().decode([String].self, from: data) {
                audioDeviceNames = parsedArray
            } else {
                audioDeviceNames = nil
            }
        } else {
            audioDeviceNames = nil
        }
        
        // Flexible is_active Dekodierung (0/1 oder true/false)
        if let boolValue = try? container.decode(Bool.self, forKey: .isActive) {
            isActive = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isActive) {
            isActive = intValue != 0
        } else {
            isActive = false // Fallback
        }
        
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
    
    // Computed property für Anzeige
    var displayName: String {
        if let brand = brand, let model = model {
            return "\(brand) \(model)"
        } else if let brand = brand {
            return brand
        } else {
            return name
        }
    }
    
    var yearDisplay: String {
        if let year = year {
            return "\(year)"
        } else {
            return ""
        }
    }
}

struct CarCreateRequest: Codable {
    let name: String
    let brand: String?
    let model: String?
    let year: Int?
    let color: String?
    let bluetoothIdentifier: String?
    let audioDeviceNames: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case model
        case year
        case color
        case bluetoothIdentifier = "bluetooth_identifier"
        case audioDeviceNames = "audio_device_names"
    }
}

struct CarUpdateRequest: Codable {
    let name: String?
    let brand: String?
    let model: String?
    let year: Int?
    let color: String?
    let bluetoothIdentifier: String?
    let audioDeviceNames: [String]?
    let isActive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case model
        case year
        case color
        case bluetoothIdentifier = "bluetooth_identifier"
        case audioDeviceNames = "audio_device_names"
        case isActive = "is_active"
    }
}

struct CarCreateResponse: Codable {
    let message: String
    let car: Car
}

struct CarUpdateResponse: Codable {
    let message: String
    let car: Car
}

struct GarageResponse: Codable {
    let cars: [Car]
}

// Auto mit Standort-Informationen
struct CarWithLocation: Codable, Identifiable {
    let id: Int
    let name: String
    let brand: String?
    let model: String?
    let year: Int?
    let color: String?
    let audioDeviceNames: [String]?
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?
    let latitude: Double?
    let longitude: Double?
    let accuracy: Double?
    let speed: Double?
    let heading: Double?
    let altitude: Double?
    let locationTimestamp: String?
    let status: String // "live", "parked", "offline"
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case model
        case year
        case color
        case audioDeviceNames = "audio_device_names"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case latitude
        case longitude
        case accuracy
        case speed
        case heading
        case altitude
        case locationTimestamp = "location_timestamp"
        case status
    }
    
    // Computed property für Anzeige
    var displayName: String {
        if let brand = brand, let model = model {
            return "\(brand) \(model)"
        } else if let brand = brand {
            return brand
        } else {
            return name
        }
    }
    
    var yearDisplay: String {
        if let year = year {
            return "\(year)"
        } else {
            return ""
        }
    }
    
    var statusColor: String {
        switch status {
        case "live":
            return "green"
        case "parked":
            return "orange"
        case "offline":
            return "gray"
        default:
            return "gray"
        }
    }
    
    var statusText: String {
        switch status {
        case "live":
            return "Live"
        case "parked":
            return "Geparkt"
        case "offline":
            return "Offline"
        default:
            return "Unbekannt"
        }
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct CarsWithLocationsResponse: Codable {
    let cars: [CarWithLocation]
}

// Auto eines Freundes mit Standort-Informationen
struct FriendCarWithLocation: Codable, Identifiable {
    let id: Int
    let name: String
    let brand: String?
    let model: String?
    let year: Int?
    let color: String?
    let audioDeviceNames: [String]?
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?
    let userId: Int
    let latitude: Double?
    let longitude: Double?
    let accuracy: Double?
    let speed: Double?
    let heading: Double?
    let altitude: Double?
    let locationTimestamp: String?
    let status: String // "live", "parked", "offline"
    let username: String?
    let displayName: String?
    let profilePictureUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case model
        case year
        case color
        case audioDeviceNames = "audio_device_names"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
        case latitude
        case longitude
        case accuracy
        case speed
        case heading
        case altitude
        case locationTimestamp = "location_timestamp"
        case status
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
    }
    
    var yearDisplay: String {
        if let year = year {
            return "\(year)"
        } else {
            return ""
        }
    }
    
    var statusColor: String {
        switch status {
        case "live":
            return "green"
        case "parked":
            return "orange"
        case "offline":
            return "gray"
        default:
            return "gray"
        }
    }
    
    var statusText: String {
        switch status {
        case "live":
            return "Live"
        case "parked":
            return "Geparkt"
        case "offline":
            return "Offline"
        default:
            return "Unbekannt"
        }
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var ownerDisplayName: String {
        return self.displayName ?? username ?? "Unbekannt"
    }
    
    var carDisplayName: String {
        if let brand = brand, let model = model {
            return "\(brand) \(model)"
        } else if let brand = brand {
            return brand
        } else {
            return name
        }
    }
}

struct FriendsCarsWithLocationsResponse: Codable {
    let cars: [FriendCarWithLocation]
}

// Bluetooth-Gerät Modell
struct BluetoothDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let isConnected: Bool
    let signalStrength: Int?
    
    init(id: String, name: String, isConnected: Bool = false, signalStrength: Int? = nil) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.signalStrength = signalStrength
    }
    
    // Equatable conformance
    static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        return lhs.id == rhs.id
    }
}
