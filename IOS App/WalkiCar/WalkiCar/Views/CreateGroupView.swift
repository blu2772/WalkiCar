//
//  CreateGroupView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var groupManager: GroupManager
    @ObservedObject var friendsManager: FriendsManager
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedFriends: Set<Int> = []
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Text("Neue Gruppe erstellen")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Wähle Freunde aus, die du zu deiner Gruppe hinzufügen möchtest")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Group Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gruppenname")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("z.B. Arbeitskollegen", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.black)
                }
                
                // Group Description Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Beschreibung (optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("z.B. Für die tägliche Fahrt zur Arbeit", text: $groupDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.black)
                }
                
                // Friends Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Freunde auswählen")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if friendsManager.friends.isEmpty {
                        Text("Keine Freunde verfügbar")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(friendsManager.friends) { friend in
                                    FriendSelectionRow(
                                        friend: friend,
                                        isSelected: selectedFriends.contains(friend.id)
                                    ) {
                                        if selectedFriends.contains(friend.id) {
                                            selectedFriends.remove(friend.id)
                                        } else {
                                            selectedFriends.insert(friend.id)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
                
                // Create Button
                Button(action: createGroup) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isCreating ? "Erstelle..." : "Gruppe erstellen")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedFriends.isEmpty || groupName.isEmpty ? Color.gray : Color.blue)
                    )
                    .foregroundColor(.white)
                }
                .disabled(selectedFriends.isEmpty || groupName.isEmpty || isCreating)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .background(Color.black.ignoresSafeArea())
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
        .onAppear {
            friendsManager.loadFriends()
        }
    }
    
    private func createGroup() {
        guard !groupName.isEmpty && !selectedFriends.isEmpty else { return }
        
        isCreating = true
        
        groupManager.createGroup(
            name: groupName,
            description: groupDescription.isEmpty ? "" : groupDescription,
            friendIds: Array(selectedFriends)
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isCreating = false
            dismiss()
        }
    }
}

struct FriendSelectionRow: View {
    let friend: Friend
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Profile Picture
            AsyncImage(url: URL(string: friend.profilePictureUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray)
                    .overlay(
                        Text(String(friend.displayName.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Friend Info
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("@\(friend.username)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Online Status
            HStack(spacing: 4) {
                Circle()
                    .fill(friend.isOnline ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(friend.isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Selection Indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    CreateGroupView(
        groupManager: GroupManager(),
        friendsManager: FriendsManager()
    )
}
