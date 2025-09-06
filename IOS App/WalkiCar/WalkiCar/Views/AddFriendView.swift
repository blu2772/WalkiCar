//
//  AddFriendView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct AddFriendView: View {
    @ObservedObject var friendsManager: FriendsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Benutzername suchen", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchText.isEmpty {
                            Button("Suchen") {
                                performSearch()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Search results
                    if isSearching {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("Suche läuft...")
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                        }
                        .padding(.top, 50)
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        VStack {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Keine Benutzer gefunden")
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                        }
                        .padding(.top, 50)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { user in
                                    UserSearchResultView(
                                        user: user,
                                        onAddFriend: {
                                            friendsManager.sendFriendRequest(username: user.username)
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Freund hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        Task {
            let results = await friendsManager.searchUsers(query: searchText)
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
}

struct UserSearchResultView: View {
    let user: UserSearchResult
    let onAddFriend: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile picture placeholder
            ZStack {
                Circle()
                    .fill(user.isOnline ? Color.green : Color.gray)
                    .frame(width: 40, height: 40)
                
                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("@\(user.username)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Action button based on relationship status
            switch user.relationshipStatus {
            case "none":
                Button("Hinzufügen") {
                    onAddFriend()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
                
            case "pending":
                Text("Ausstehend")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                
            case "friend":
                Text("Bereits befreundet")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                
            case "blocked":
                Text("Blockiert")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    AddFriendView(friendsManager: FriendsManager())
}
