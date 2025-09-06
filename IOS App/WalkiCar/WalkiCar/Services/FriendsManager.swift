//
//  FriendsManager.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import Foundation

@MainActor
class FriendsManager: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    var onlineFriendsCount: Int {
        friends.filter { $0.isOnline }.count
    }
    
    func loadFriends() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await apiClient.getFriendsList()
                await MainActor.run {
                    self.friends = response.friends
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadFriendRequests() {
        Task {
            do {
                let response = try await apiClient.getFriendRequests()
                await MainActor.run {
                    self.friendRequests = response.requests
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func sendFriendRequest(username: String) {
        Task {
            do {
                try await apiClient.sendFriendRequest(username: username)
                await MainActor.run {
                    // Reload friends to update the list
                    self.loadFriends()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func respondToFriendRequest(friendshipId: Int, action: String) {
        Task {
            do {
                try await apiClient.respondToFriendRequest(friendshipId: friendshipId, action: action)
                await MainActor.run {
                    // Reload both friends and requests
                    self.loadFriends()
                    self.loadFriendRequests()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func removeFriend(friendshipId: Int) {
        Task {
            do {
                try await apiClient.removeFriend(friendshipId: friendshipId)
                await MainActor.run {
                    // Remove from local array
                    self.friends.removeAll { $0.friendshipId == friendshipId }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func searchUsers(query: String) async -> [UserSearchResult] {
        do {
            let response = try await apiClient.searchUsers(query: query)
            return response.users
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return []
        }
    }
}
