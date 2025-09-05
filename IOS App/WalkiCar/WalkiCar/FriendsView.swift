import SwiftUI
import Combine

// MARK: - Friends Data Models
struct Friend: Codable, Identifiable {
  let id: Int
  let display_name: String
  let avatar_url: String?
}

struct FriendRequest: Codable, Identifiable {
  let id: Int
  let user: Friend
  let status: String
  let created_at: String
}

// MARK: - Friends Service
class FriendsService: ObservableObject {
  @Published var friends: [Friend] = []
  @Published var pendingRequests: [FriendRequest] = []
  @Published var searchResults: [Friend] = []
  
  private let apiService = APIService()
  
  func searchUsers(query: String) async {
    do {
      let results = try await apiService.searchUsers(query: query)
      await MainActor.run {
        self.searchResults = results
      }
    } catch {
      print("❌ User search failed: \(error)")
    }
  }
  
  func sendFriendRequest(userId: Int) async {
    do {
      try await apiService.sendFriendRequest(userId: userId)
      print("✅ Friend request sent to user \(userId)")
    } catch {
      print("❌ Failed to send friend request: \(error)")
    }
  }
  
  func acceptFriendRequest(requestId: Int) async {
    do {
      try await apiService.acceptFriendRequest(requestId: requestId)
      await loadPendingRequests()
      await loadFriends()
    } catch {
      print("❌ Failed to accept friend request: \(error)")
    }
  }
  
  func rejectFriendRequest(requestId: Int) async {
    do {
      try await apiService.rejectFriendRequest(requestId: requestId)
      await loadPendingRequests()
    } catch {
      print("❌ Failed to reject friend request: \(error)")
    }
  }
  
  func removeFriend(friendId: Int) async {
    do {
      try await apiService.removeFriend(friendId: friendId)
      await loadFriends()
    } catch {
      print("❌ Failed to remove friend: \(error)")
    }
  }
  
  func loadFriends() async {
    do {
      let friends = try await apiService.getFriends()
      await MainActor.run {
        self.friends = friends
      }
    } catch {
      print("❌ Failed to load friends: \(error)")
    }
  }
  
  func loadPendingRequests() async {
    do {
      let requests = try await apiService.getPendingRequests()
      await MainActor.run {
        self.pendingRequests = requests
      }
    } catch {
      print("❌ Failed to load pending requests: \(error)")
    }
  }
}

// MARK: - Friends View
struct FriendsView: View {
  @StateObject private var friendsService = FriendsService()
  @State private var searchText = ""
  @State private var showingSearch = false
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 0) {
          // Search Bar
          HStack {
            TextField("Search users...", text: $searchText)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .onSubmit {
                Task {
                  await friendsService.searchUsers(query: searchText)
                  showingSearch = true
                }
              }
            
            Button("Search") {
              Task {
                await friendsService.searchUsers(query: searchText)
                showingSearch = true
              }
            }
            .foregroundColor(.blue)
          }
          .padding()
          
          if showingSearch {
            // Search Results
            SearchResultsView(
              searchResults: friendsService.searchResults,
              onSendRequest: { userId in
                Task {
                  await friendsService.sendFriendRequest(userId: userId)
                  showingSearch = false
                  searchText = ""
                }
              }
            )
          } else {
            // Friends List
            ScrollView {
              LazyVStack(spacing: 12) {
                // Pending Requests Section
                if !friendsService.pendingRequests.isEmpty {
                  VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Requests")
                      .font(.headline)
                      .foregroundColor(.white)
                      .padding(.horizontal)
                    
                    ForEach(friendsService.pendingRequests) { request in
                      PendingRequestRow(
                        request: request,
                        onAccept: { requestId in
                          Task {
                            await friendsService.acceptFriendRequest(requestId: requestId)
                          }
                        },
                        onReject: { requestId in
                          Task {
                            await friendsService.rejectFriendRequest(requestId: requestId)
                          }
                        }
                      )
                    }
                  }
                  .padding(.bottom)
                }
                
                // Friends Section
                VStack(alignment: .leading, spacing: 8) {
                  Text("Friends (\(friendsService.friends.count))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                  
                  ForEach(friendsService.friends) { friend in
                    FriendRow(
                      friend: friend,
                      onRemove: { friendId in
                        Task {
                          await friendsService.removeFriend(friendId: friendId)
                        }
                      }
                    )
                  }
                }
              }
              .padding()
            }
          }
        }
      }
      .navigationTitle("Friends")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        Task {
          await friendsService.loadFriends()
          await friendsService.loadPendingRequests()
        }
      }
    }
  }
}

// MARK: - Search Results View
struct SearchResultsView: View {
  let searchResults: [Friend]
  let onSendRequest: (Int) -> Void
  
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(searchResults) { user in
          SearchResultRow(
            user: user,
            onSendRequest: { userId in
              onSendRequest(userId)
            }
          )
        }
      }
      .padding()
    }
  }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
  let user: Friend
  let onSendRequest: (Int) -> Void
  
  var body: some View {
    HStack {
      // Avatar placeholder
      Circle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 40, height: 40)
        .overlay(
          Text(String(user.display_name.prefix(1)))
            .font(.headline)
            .foregroundColor(.white)
        )
      
      VStack(alignment: .leading, spacing: 4) {
        Text(user.display_name)
          .font(.headline)
          .foregroundColor(.white)
        
        Text("Tap to send friend request")
          .font(.caption)
          .foregroundColor(.gray)
      }
      
      Spacer()
      
      Button("Add") {
        onSendRequest(user.id)
      }
      .foregroundColor(.blue)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color.blue.opacity(0.2))
      .cornerRadius(8)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
}

// MARK: - Pending Request Row
struct PendingRequestRow: View {
  let request: FriendRequest
  let onAccept: (Int) -> Void
  let onReject: (Int) -> Void
  
  var body: some View {
    HStack {
      // Avatar placeholder
      Circle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 40, height: 40)
        .overlay(
          Text(String(request.user.display_name.prefix(1)))
            .font(.headline)
            .foregroundColor(.white)
        )
      
      VStack(alignment: .leading, spacing: 4) {
        Text(request.user.display_name)
          .font(.headline)
          .foregroundColor(.white)
        
        Text("Wants to be your friend")
          .font(.caption)
          .foregroundColor(.gray)
      }
      
      Spacer()
      
      HStack(spacing: 8) {
        Button("Accept") {
          onAccept(request.id)
        }
        .foregroundColor(.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.2))
        .cornerRadius(6)
        
        Button("Reject") {
          onReject(request.id)
        }
        .foregroundColor(.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.2))
        .cornerRadius(6)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
}

// MARK: - Friend Row
struct FriendRow: View {
  let friend: Friend
  let onRemove: (Int) -> Void
  
  var body: some View {
    HStack {
      // Avatar placeholder
      Circle()
        .fill(Color.green.opacity(0.3))
        .frame(width: 40, height: 40)
        .overlay(
          Text(String(friend.display_name.prefix(1)))
            .font(.headline)
            .foregroundColor(.white)
        )
      
      VStack(alignment: .leading, spacing: 4) {
        Text(friend.display_name)
          .font(.headline)
          .foregroundColor(.white)
        
        Text("Online")
          .font(.caption)
          .foregroundColor(.green)
      }
      
      Spacer()
      
      Button("Remove") {
        onRemove(friend.id)
      }
      .foregroundColor(.red)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color.red.opacity(0.2))
      .cornerRadius(6)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
}

// MARK: - API Service Extensions
extension APIService {
  func searchUsers(query: String) async throws -> [Friend] {
    guard let url = URL(string: "\(baseURL)/friends/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
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
    
    return try JSONDecoder().decode([Friend].self, from: data)
  }
  
  func sendFriendRequest(userId: Int) async throws {
    guard let url = URL(string: "\(baseURL)/friends/requests") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(["userId": userId])
    // Add JWT token here
    
    let (_, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 201 else {
      throw APIError.invalidResponse
    }
  }
  
  func acceptFriendRequest(requestId: Int) async throws {
    guard let url = URL(string: "\(baseURL)/friends/requests/\(requestId)/accept") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "PATCH"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add JWT token here
    
    let (_, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
  }
  
  func rejectFriendRequest(requestId: Int) async throws {
    guard let url = URL(string: "\(baseURL)/friends/requests/\(requestId)/reject") else {
      throw APIError.invalidURL
    }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "PATCH"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Add JWT token here
    
    let (_, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
      throw APIError.invalidResponse
    }
  }
  
  func getFriends() async throws -> [Friend] {
    guard let url = URL(string: "\(baseURL)/friends") else {
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
    
    return try JSONDecoder().decode([Friend].self, from: data)
  }
  
  func getPendingRequests() async throws -> [FriendRequest] {
    guard let url = URL(string: "\(baseURL)/friends/requests") else {
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
    
    return try JSONDecoder().decode([FriendRequest].self, from: data)
  }
  
  func removeFriend(friendId: Int) async throws {
    guard let url = URL(string: "\(baseURL)/friends/\(friendId)") else {
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
}
