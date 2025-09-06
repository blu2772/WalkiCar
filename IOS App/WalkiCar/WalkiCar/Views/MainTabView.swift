//
//  MainTabView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        TabView {
            // Map Tab
            CarMapView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Karte")
                }
            
            // Voice Chat Tab
            VoiceChatView()
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Voice Chat")
                }
            
            // Friends Tab
            FriendsView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Freunde")
                }
            
            // Garage Tab
            GarageView()
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Garage")
                }
        }
        .accentColor(.white)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
}
