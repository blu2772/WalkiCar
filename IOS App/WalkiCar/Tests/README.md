# WalkiCar iOS Tests

## Unit Tests
- **AuthManager**: Sign in with Apple flow
- **AudioRoutingManager**: Audio session configuration
- **APIService**: Network requests and responses
- **ViewModels**: Business logic and state management

## UI Tests
- **Welcome Screen**: Sign in flow
- **Map View**: Location permissions and vehicle display
- **Voice Chat**: Push-to-Talk functionality
- **Garage**: Vehicle management

## Test Structure
```
WalkiCarTests/
├── AuthManagerTests.swift
├── AudioRoutingManagerTests.swift
├── APIServiceTests.swift
└── ViewModelTests.swift

WalkiCarUITests/
├── WelcomeViewUITests.swift
├── MapViewUITests.swift
├── VoiceChatUITests.swift
└── GarageUITests.swift
```

## Running Tests
- **Unit Tests**: Cmd+U in Xcode
- **UI Tests**: Select test target and run
- **Coverage**: Enable in Xcode scheme settings

## Mocking
- **APIService**: Mock responses for testing
- **LocationManager**: Mock location data
- **AudioSession**: Mock audio routing
- **UserDefaults**: Isolated test storage
