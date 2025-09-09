//
//  FriendsView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct FriendsView: View {
    @StateObject private var friendsManager = FriendsManager()
    @State private var showingAddFriend = false
    @State private var showingFriendRequests = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Freunde")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 15) {
                            // Friend requests button
                            Button(action: { showingFriendRequests = true }) {
                                ZStack {
                                    Image(systemName: "person.crop.circle.badge.questionmark")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                    
                                    if !friendsManager.friendRequests.isEmpty {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }
                            
                            // Add friend button
                            Button(action: { showingAddFriend = true }) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Friends Online Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Friends Online")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Online count badge
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 24)
                                
                                Text("\(friendsManager.onlineFriendsCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        if friendsManager.isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Lade Freunde...")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                        } else if friendsManager.friends.isEmpty {
                            Text("Noch keine Freunde hinzugefügt")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(friendsManager.friends) { friend in
                                    FriendRowView(friend: friend)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(friendsManager: friendsManager)
        }
        .sheet(isPresented: $showingFriendRequests) {
            FriendRequestsView(friendsManager: friendsManager)
        }
        .onAppear {
            friendsManager.loadFriends()
            friendsManager.loadFriendRequests()
        }
    }
}

struct FriendRowView: View {
    let friend: Friend
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile picture placeholder
            ZStack {
                Circle()
                    .fill(friend.isOnline ? Color.green : Color.gray)
                    .frame(width: 40, height: 40)
                
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                if let car = friend.activeCar {
                    Text(car.name)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                } else {
                    Text(friend.isOnline ? "Online" : "Offline")
                        .font(.system(size: 14))
                        .foregroundColor(friend.isOnline ? .green : .gray)
                }
            }
            
            Spacer()
            
            // Online indicator
            if friend.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    FriendsView()
}
