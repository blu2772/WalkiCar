//
//  SettingsView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var authManager: AuthManager
  @EnvironmentObject var audioManager: AudioRoutingManager
  @State private var showingSignOutAlert = false
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black
          .ignoresSafeArea()
        
        List {
          // User Profile Section
          Section {
            HStack {
              Circle()
                .fill(Color.blue)
                .frame(width: 60, height: 60)
                .overlay(
                  Text(authManager.currentUser?.displayName.prefix(1) ?? "U")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                )
              
              VStack(alignment: .leading) {
                Text(authManager.currentUser?.displayName ?? "User")
                  .font(.headline)
                  .foregroundColor(.white)
                
                Text("WalkiCar User")
                  .font(.caption)
                  .foregroundColor(.gray)
              }
              
              Spacer()
            }
            .padding(.vertical, 8)
          }
          
          // Audio Settings Section
          Section("Audio Settings") {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Audio Mode")
                  .foregroundColor(.white)
                Spacer()
                Picker("Audio Mode", selection: $audioManager.currentMode) {
                  Text("Music Priority").tag(AudioRoutingMode.musicPriority)
                  Text("Hands-Free Priority").tag(AudioRoutingMode.handsFreePriority)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
              }
              
              Text(audioManager.getAudioRouteDescription())
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
          }
          
          // Privacy Settings Section
          Section("Privacy") {
            NavigationLink(destination: PrivacySettingsView()) {
              HStack {
                Image(systemName: "lock.shield")
                  .foregroundColor(.blue)
                Text("Privacy Settings")
                  .foregroundColor(.white)
              }
            }
            
            NavigationLink(destination: FriendsSettingsView()) {
              HStack {
                Image(systemName: "person.2")
                  .foregroundColor(.green)
                Text("Friends Management")
                  .foregroundColor(.white)
              }
            }
          }
          
          // App Settings Section
          Section("App") {
            NavigationLink(destination: NotificationsSettingsView()) {
              HStack {
                Image(systemName: "bell")
                  .foregroundColor(.orange)
                Text("Notifications")
                  .foregroundColor(.white)
              }
            }
            
            NavigationLink(destination: AboutView()) {
              HStack {
                Image(systemName: "info.circle")
                  .foregroundColor(.gray)
                Text("About WalkiCar")
                  .foregroundColor(.white)
              }
            }
          }
          
          // Account Section
          Section("Account") {
            Button(action: { showingSignOutAlert = true }) {
              HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                  .foregroundColor(.red)
                Text("Sign Out")
                  .foregroundColor(.red)
              }
            }
          }
        }
        .listStyle(InsetGroupedListStyle())
        .preferredColorScheme(.dark)
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .alert("Sign Out", isPresented: $showingSignOutAlert) {
        Button("Cancel", role: .cancel) { }
        Button("Sign Out", role: .destructive) {
          authManager.signOut()
        }
      } message: {
        Text("Are you sure you want to sign out?")
      }
    }
  }
}

struct PrivacySettingsView: View {
  @State private var locationSharing = true
  @State private var vehicleTracking = true
  @State private var friendVisibility = true
  
  var body: some View {
    List {
      Section("Location Sharing") {
        Toggle("Share Location with Friends", isOn: $locationSharing)
        Toggle("Allow Vehicle Tracking", isOn: $vehicleTracking)
      }
      
      Section("Visibility") {
        Toggle("Visible to Friends", isOn: $friendVisibility)
      }
      
      Section("Data") {
        NavigationLink("Manage Data") {
          Text("Data Management")
        }
      }
    }
    .navigationTitle("Privacy")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
  }
}

struct FriendsSettingsView: View {
  @StateObject private var friendsViewModel = FriendsViewModel()
  
  var body: some View {
    List {
      Section("Friend Requests") {
        ForEach(friendsViewModel.pendingRequests) { request in
          HStack {
            Circle()
              .fill(Color.blue)
              .frame(width: 40, height: 40)
              .overlay(
                Text(request.friend.displayName.prefix(1))
                  .font(.headline)
                  .foregroundColor(.white)
              )
            
            VStack(alignment: .leading) {
              Text(request.friend.displayName)
                .font(.headline)
                .foregroundColor(.white)
              
              Text("Wants to be friends")
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack {
              Button("Accept") {
                friendsViewModel.acceptRequest(requestId: request.id)
              }
              .font(.caption)
              .foregroundColor(.green)
              
              Button("Decline") {
                friendsViewModel.declineRequest(requestId: request.id)
              }
              .font(.caption)
              .foregroundColor(.red)
            }
          }
        }
      }
      
      Section("Friends") {
        ForEach(friendsViewModel.friends) { friendship in
          HStack {
            Circle()
              .fill(Color.green)
              .frame(width: 40, height: 40)
              .overlay(
                Text(friendship.friend.displayName.prefix(1))
                  .font(.headline)
                  .foregroundColor(.white)
              )
            
            Text(friendship.friend.displayName)
              .foregroundColor(.white)
            
            Spacer()
            
            Button("Remove") {
              friendsViewModel.removeFriend(friendId: friendship.friendId)
            }
            .font(.caption)
            .foregroundColor(.red)
          }
        }
      }
    }
    .navigationTitle("Friends")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
    .onAppear {
      friendsViewModel.loadFriends()
    }
  }
}

struct NotificationsSettingsView: View {
  @State private var voiceChatNotifications = true
  @State private var friendRequests = true
  @State private var vehicleAlerts = true
  
  var body: some View {
    List {
      Section("Notifications") {
        Toggle("Voice Chat", isOn: $voiceChatNotifications)
        Toggle("Friend Requests", isOn: $friendRequests)
        Toggle("Vehicle Alerts", isOn: $vehicleAlerts)
      }
    }
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
  }
}

struct AboutView: View {
  var body: some View {
    List {
      Section("App Information") {
        HStack {
          Text("Version")
            .foregroundColor(.white)
          Spacer()
          Text("1.0.0")
            .foregroundColor(.gray)
        }
        
        HStack {
          Text("Build")
            .foregroundColor(.white)
          Spacer()
          Text("1")
            .foregroundColor(.gray)
        }
      }
      
      Section("Support") {
        NavigationLink("Contact Support") {
          Text("Support")
        }
        
        NavigationLink("Privacy Policy") {
          Text("Privacy Policy")
        }
        
        NavigationLink("Terms of Service") {
          Text("Terms of Service")
        }
      }
    }
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
  }
}

class FriendsViewModel: ObservableObject {
  @Published var friends: [Friendship] = []
  @Published var pendingRequests: [Friendship] = []
  
  private let apiService = APIService()
  private var cancellables = Set<AnyCancellable>()
  
  func loadFriends() {
    apiService.getFriends()
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to load friends: \(error)")
          }
        },
        receiveValue: { [weak self] friendships in
          self?.friends = friendships.filter { $0.status == "accepted" }
          self?.pendingRequests = friendships.filter { $0.status == "pending" }
        }
      )
      .store(in: &cancellables)
  }
  
  func acceptRequest(requestId: Int) {
    // Implement accept request logic
    loadFriends()
  }
  
  func declineRequest(requestId: Int) {
    // Implement decline request logic
    loadFriends()
  }
  
  func removeFriend(friendId: Int) {
    // Implement remove friend logic
    loadFriends()
  }
}

#Preview {
  SettingsView()
    .environmentObject(AuthManager())
    .environmentObject(AudioRoutingManager())
}
