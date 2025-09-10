//
//  Car.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation

struct Car: Codable, Identifiable {
    let id: Int
    let name: String
    let brand: String?
    let model: String?
    let year: Int?
    let color: String?
    let bluetoothIdentifier: String?
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
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Manual initializer
    init(id: Int, name: String, brand: String?, model: String?, year: Int?, color: String?, bluetoothIdentifier: String?, isActive: Bool, createdAt: String?, updatedAt: String?) {
        self.id = id
        self.name = name
        self.brand = brand
        self.model = model
        self.year = year
        self.color = color
        self.bluetoothIdentifier = bluetoothIdentifier
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
    
    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case model
        case year
        case color
        case bluetoothIdentifier = "bluetooth_identifier"
    }
}

struct CarUpdateRequest: Codable {
    let name: String?
    let brand: String?
    let model: String?
    let year: Int?
    let color: String?
    let bluetoothIdentifier: String?
    let isActive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case model
        case year
        case color
        case bluetoothIdentifier = "bluetooth_identifier"
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

// Bluetooth-Gerät Modell
struct BluetoothDevice: Identifiable {
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
}
