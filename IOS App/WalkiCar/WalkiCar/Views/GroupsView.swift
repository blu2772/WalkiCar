//
//  GroupsView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct GroupsView: View {
  @StateObject private var groupsViewModel = GroupsViewModel()
  @EnvironmentObject var authManager: AuthManager
  @State private var showingCreateGroup = false
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.black
          .ignoresSafeArea()
        
        VStack {
          if groupsViewModel.groups.isEmpty {
            EmptyGroupsView()
          } else {
            ScrollView {
              LazyVStack(spacing: 16) {
                ForEach(groupsViewModel.groups) { group in
                  GroupCardView(group: group) {
                    groupsViewModel.joinGroup(groupId: group.id)
                  }
                }
              }
              .padding()
            }
          }
        }
        
        VStack {
          Spacer()
          
          Button(action: { showingCreateGroup = true }) {
            Image(systemName: "plus")
              .font(.title2)
              .foregroundColor(.white)
              .frame(width: 56, height: 56)
              .background(Color.blue)
              .clipShape(Circle())
          }
          .padding(.bottom, 20)
        }
      }
      .navigationTitle("Groups")
      .navigationBarTitleDisplayMode(.large)
      .preferredColorScheme(.dark)
      .sheet(isPresented: $showingCreateGroup) {
        CreateGroupView { name, description, isPublic in
          groupsViewModel.createGroup(name: name, description: description, isPublic: isPublic)
        }
      }
    }
    .onAppear {
      groupsViewModel.loadGroups()
    }
  }
}

struct GroupCardView: View {
  let group: Group
  let onJoin: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(group.name)
            .font(.headline)
            .foregroundColor(.white)
          
          if let description = group.description {
            Text(description)
              .font(.caption)
              .foregroundColor(.gray)
          }
        }
        
        Spacer()
        
        VStack {
          Text("\(group.memberCount)")
            .font(.caption)
            .foregroundColor(.green)
          
          Image(systemName: "person.3.fill")
            .foregroundColor(.green)
        }
      }
      
      HStack {
        Button(action: onJoin) {
          Text("Join")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(16)
        }
        
        Spacer()
        
        NavigationLink(destination: VoiceChatView(group: group)) {
          Text("Voice Chat")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green)
            .cornerRadius(16)
        }
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
}

struct EmptyGroupsView: View {
  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "person.3")
        .font(.system(size: 60))
        .foregroundColor(.gray)
      
      Text("No Groups Yet")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
      
      Text("Create or join a group to start voice chatting with friends")
        .font(.body)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct CreateGroupView: View {
  @Environment(\.dismiss) private var dismiss
  let onCreate: (String, String?, Bool) -> Void
  
  @State private var name = ""
  @State private var description = ""
  @State private var isPublic = false
  
  var body: some View {
    NavigationView {
      Form {
        Section("Group Details") {
          TextField("Group Name", text: $name)
          TextField("Description (Optional)", text: $description, axis: .vertical)
            .lineLimit(3...6)
        }
        
        Section("Privacy") {
          Toggle("Public Group", isOn: $isPublic)
        }
      }
      .navigationTitle("Create Group")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Create") {
            onCreate(name, description.isEmpty ? nil : description, isPublic)
            dismiss()
          }
          .disabled(name.isEmpty)
        }
      }
    }
  }
}

class GroupsViewModel: ObservableObject {
  @Published var groups: [Group] = []
  
  private let apiService = APIService()
  private var cancellables = Set<AnyCancellable>()
  
  func loadGroups() {
    apiService.getGroups()
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to load groups: \(error)")
          }
        },
        receiveValue: { [weak self] groups in
          self?.groups = groups
        }
      )
      .store(in: &cancellables)
  }
  
  func createGroup(name: String, description: String?, isPublic: Bool) {
    apiService.createGroup(name: name, description: description, isPublic: isPublic)
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to create group: \(error)")
          }
        },
        receiveValue: { [weak self] _ in
          self?.loadGroups()
        }
      )
      .store(in: &cancellables)
  }
  
  func joinGroup(groupId: Int) {
    apiService.joinGroup(groupId: groupId)
      .sink(
        receiveCompletion: { completion in
          if case .failure(let error) = completion {
            print("Failed to join group: \(error)")
          }
        },
        receiveValue: { [weak self] _ in
          self?.loadGroups()
        }
      )
      .store(in: &cancellables)
  }
}

#Preview {
  GroupsView()
    .environmentObject(AuthManager())
    .environmentObject(AudioRoutingManager())
}
