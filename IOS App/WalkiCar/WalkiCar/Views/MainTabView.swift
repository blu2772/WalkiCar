//
//  MainTabView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct MainTabView: View {
  @State private var selectedTab = 0
  
  var body: some View {
    TabView(selection: $selectedTab) {
      MapView()
        .tabItem {
          Image(systemName: "map")
          Text("Map")
        }
        .tag(0)
      
      GroupsView()
        .tabItem {
          Image(systemName: "person.3")
          Text("Groups")
        }
        .tag(1)
      
      GarageView()
        .tabItem {
          Image(systemName: "car")
          Text("Garage")
        }
        .tag(2)
      
      SettingsView()
        .tabItem {
          Image(systemName: "gear")
          Text("Settings")
        }
        .tag(3)
    }
    .accentColor(.white)
    .preferredColorScheme(.dark)
  }
}

#Preview {
  MainTabView()
    .environmentObject(AuthManager())
    .environmentObject(AudioRoutingManager())
}
