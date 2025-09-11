import Foundation

// MARK: - Location Models

struct Location: Codable, Identifiable {
    let id: Int
    let userId: Int
    let carId: Int?
    let latitude: Double
    let longitude: Double
    let accuracy: Float?
    let speed: Float?
    let heading: Float?
    let altitude: Float?
    let isLive: Bool?
    let isParked: Bool?
    let bluetoothConnected: Bool?
    let timestamp: String
    
    // User info (from JOIN queries)
    let username: String?
    let displayName: String?
    let profilePictureUrl: String?
    
    // Car info (from JOIN queries)
    let carName: String?
    let brand: String?
    let model: String?
    let color: String?
    
    // Custom initializer für flexible latitude/longitude Dekodierung
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        carId = try container.decodeIfPresent(Int.self, forKey: .carId)
        
        // Flexible latitude Dekodierung (Double oder String)
        if let doubleValue = try? container.decode(Double.self, forKey: .latitude) {
            latitude = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .latitude),
                  let parsedValue = Double(stringValue) {
            latitude = parsedValue
        } else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode latitude as Double or String"))
        }
        
        // Flexible longitude Dekodierung (Double oder String)
        if let doubleValue = try? container.decode(Double.self, forKey: .longitude) {
            longitude = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .longitude),
                  let parsedValue = Double(stringValue) {
            longitude = parsedValue
        } else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode longitude as Double or String"))
        }
        
        accuracy = try container.decodeIfPresent(Float.self, forKey: .accuracy)
        speed = try container.decodeIfPresent(Float.self, forKey: .speed)
        heading = try container.decodeIfPresent(Float.self, forKey: .heading)
        altitude = try container.decodeIfPresent(Float.self, forKey: .altitude)
        isLive = try container.decodeIfPresent(Bool.self, forKey: .isLive)
        isParked = try container.decodeIfPresent(Bool.self, forKey: .isParked)
        bluetoothConnected = try container.decodeIfPresent(Bool.self, forKey: .bluetoothConnected)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        
        username = try container.decodeIfPresent(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        
        carName = try container.decodeIfPresent(String.self, forKey: .carName)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        color = try container.decodeIfPresent(String.self, forKey: .color)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carId = "car_id"
        case latitude, longitude, accuracy, speed, heading, altitude
        case isLive = "is_live"
        case isParked = "is_parked"
        case bluetoothConnected = "bluetooth_connected"
        case timestamp
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
        case carName = "car_name"
        case brand, model, color
    }
}

struct ParkedLocation: Codable, Identifiable {
    let id: Int
    let userId: Int
    let carId: Int?
    let latitude: Double
    let longitude: Double
    let accuracy: Float?
    let parkedAt: String
    let lastLiveUpdate: String?
    
    // User info (from JOIN queries)
    let username: String?
    let displayName: String?
    let profilePictureUrl: String?
    
    // Car info (from JOIN queries)
    let carName: String?
    let brand: String?
    let model: String?
    let color: String?
    
    // Custom initializer für flexible latitude/longitude Dekodierung
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        carId = try container.decodeIfPresent(Int.self, forKey: .carId)
        
        // Flexible latitude Dekodierung (Double oder String)
        if let doubleValue = try? container.decode(Double.self, forKey: .latitude) {
            latitude = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .latitude),
                  let parsedValue = Double(stringValue) {
            latitude = parsedValue
        } else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode latitude as Double or String"))
        }
        
        // Flexible longitude Dekodierung (Double oder String)
        if let doubleValue = try? container.decode(Double.self, forKey: .longitude) {
            longitude = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .longitude),
                  let parsedValue = Double(stringValue) {
            longitude = parsedValue
        } else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode longitude as Double or String"))
        }
        
        accuracy = try container.decodeIfPresent(Float.self, forKey: .accuracy)
        parkedAt = try container.decode(String.self, forKey: .parkedAt)
        lastLiveUpdate = try container.decodeIfPresent(String.self, forKey: .lastLiveUpdate)
        
        username = try container.decodeIfPresent(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        
        carName = try container.decodeIfPresent(String.self, forKey: .carName)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        color = try container.decodeIfPresent(String.self, forKey: .color)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carId = "car_id"
        case latitude, longitude, accuracy
        case parkedAt = "parked_at"
        case lastLiveUpdate = "last_live_update"
        case username
        case displayName = "display_name"
        case profilePictureUrl = "profile_picture_url"
        case carName = "car_name"
        case brand, model, color
    }
}

struct LocationHistory: Codable, Identifiable {
    let id: Int
    let userId: Int
    let carId: Int?
    let latitude: Double
    let longitude: Double
    let accuracy: Float?
    let speed: Float?
    let heading: Float?
    let altitude: Float?
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carId = "car_id"
        case latitude, longitude, accuracy, speed, heading, altitude, timestamp
    }
}

// MARK: - Request Models

struct LocationUpdateRequest: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Float?
    let speed: Float?
    let heading: Float?
    let altitude: Float?
    let carId: Int?
    let bluetoothConnected: Bool?
    
    enum CodingKeys: String, CodingKey {
        case latitude, longitude, accuracy, speed, heading, altitude
        case carId = "car_id"
        case bluetoothConnected = "bluetooth_connected"
    }
}

struct ParkCarRequest: Codable {
    let carId: Int
    
    enum CodingKeys: String, CodingKey {
        case carId = "car_id"
    }
}

struct LocationSettingsRequest: Codable {
    let visibility: String
    let shareLocation: Bool
    let shareWhenMoving: Bool
    let shareWhenStationary: Bool
    let carId: Int?
    
    enum CodingKeys: String, CodingKey {
        case visibility
        case shareLocation = "share_location"
        case shareWhenMoving = "share_when_moving"
        case shareWhenStationary = "share_when_stationary"
        case carId = "car_id"
    }
}

// MARK: - Response Models

struct LocationUpdateResponse: Codable {
    let message: String
    let locationId: Int
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case locationId = "location_id"
        case timestamp
    }
}

struct LiveLocationsResponse: Codable {
    let liveLocations: [Location]
    let parkedLocations: [ParkedLocation]
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case liveLocations = "live_locations"
        case parkedLocations = "parked_locations"
        case timestamp
    }
}

struct MyLocationsResponse: Codable {
    let locations: [Location]
    let timestamp: String
}

struct LocationHistoryResponse: Codable {
    let carId: Int
    let history: [LocationHistory]
    let days: Int
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case carId = "car_id"
        case history, days, timestamp
    }
}

struct LocationSettingsResponse: Codable {
    let settings: [LocationSetting]
    let timestamp: String
}

struct LocationSetting: Codable, Identifiable {
    let id: Int
    let userId: Int
    let carId: Int?
    let visibility: String
    let shareLocation: Bool
    let shareWhenMoving: Bool
    let shareWhenStationary: Bool
    let createdAt: String
    let updatedAt: String
    
    // Car info (from JOIN queries)
    let carName: String?
    let brand: String?
    let model: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case carId = "car_id"
        case visibility
        case shareLocation = "share_location"
        case shareWhenMoving = "share_when_moving"
        case shareWhenStationary = "share_when_stationary"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case carName = "car_name"
        case brand, model
    }
}

// MARK: - Location Status Enum

enum LocationVisibility: String, CaseIterable {
    case private_ = "private"
    case friends = "friends"
    case public_ = "public"
    
    var displayName: String {
        switch self {
        case .private_:
            return "Privat"
        case .friends:
            return "Freunde"
        case .public_:
            return "Öffentlich"
        }
    }
}

// MARK: - Location Status Helper

enum LocationStatus {
    case live
    case parked
    case offline
    
    var displayName: String {
        switch self {
        case .live:
            return "Live"
        case .parked:
            return "Geparkt"
        case .offline:
            return "Offline"
        }
    }
    
    var color: String {
        switch self {
        case .live:
            return "green"
        case .parked:
            return "orange"
        case .offline:
            return "gray"
        }
    }
}
