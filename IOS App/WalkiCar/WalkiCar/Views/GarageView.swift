//
//  GarageView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI

struct GarageView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Text("Garage")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Cars list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Cupue Car
                            CarCardView(
                                carName: "Cupue",
                                carImage: "car.fill",
                                carColor: .blue,
                                visibility: "Visibility Friends",
                                tracking: "Tracking While Driveg",
                                friendCount: 0
                            )
                            
                            // SUV Car
                            CarCardView(
                                carName: "SUV",
                                carImage: "car.fill",
                                carColor: .white,
                                visibility: "Visibility Everyone",
                                tracking: "Tracking Always",
                                friendCount: 2
                            )
                            
                            // Gnoross Car
                            CarCardView(
                                carName: "Gnoross",
                                carImage: "car.fill",
                                carColor: .gray,
                                visibility: "Visibility Private",
                                tracking: "Tracking Disabled",
                                friendCount: 0
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct CarCardView: View {
    let carName: String
    let carImage: String
    let carColor: Color
    let visibility: String
    let tracking: String
    let friendCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: carImage)
                    .font(.system(size: 40))
                    .foregroundColor(carColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(carName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(visibility)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text(tracking)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(0..<friendCount, id: \.self) { _ in
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    
                    Text("\(friendCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    GarageView()
}
