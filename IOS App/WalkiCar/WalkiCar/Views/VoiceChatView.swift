//
//  VoiceChatView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct VoiceChatView: View {
    @State private var isRecording = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // Header
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Text("Voice Chat")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Microphone button
                    Button(action: {
                        isRecording.toggle()
                    }) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color.blue)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isRecording)
                    
                    // Participants list
                    VStack(spacing: 12) {
                        Text("Tim")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                        
                        Text("Lauren")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                        
                        Text("Drew")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                        
                        Text("Nicole")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    VoiceChatView()
}
