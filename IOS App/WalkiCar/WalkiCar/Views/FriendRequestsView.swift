//
//  FriendRequestsView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var friendsManager: FriendsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if friendsManager.friendRequests.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Keine Freundschaftsanfragen")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text("Du hast derzeit keine ausstehenden Freundschaftsanfragen.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 100)
                        
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(friendsManager.friendRequests) { request in
                                    FriendRequestRowView(
                                        request: request,
                                        onAccept: {
                                            friendsManager.respondToFriendRequest(
                                                friendshipId: request.id,
                                                action: "accept"
                                            )
                                        },
                                        onDecline: {
                                            friendsManager.respondToFriendRequest(
                                                friendshipId: request.id,
                                                action: "decline"
                                            )
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationTitle("Freundschaftsanfragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct FriendRequestRowView: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile picture placeholder
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                
                Text(String(request.displayName.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("@\(request.username)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text("Möchte dein Freund werden")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 8) {
                Button("Annehmen") {
                    onAccept()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green)
                .cornerRadius(8)
                
                Button("Ablehnen") {
                    onDecline()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    FriendRequestsView(friendsManager: FriendsManager())
}
