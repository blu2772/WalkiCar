//
//  CarMapView.swift
//  WalkiCar
//
//  Created by Tim Rempel on 05.09.25.
//

import SwiftUI
import MapKit

struct CarMapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Car Map")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Map placeholder
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .cornerRadius(12)
                        
                        VStack {
                            Image(systemName: "map.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Karte wird geladen...")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Friends Online Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Friends Online")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 24)
                                
                                Text("0")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text("Ashley")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                        
                        Text("Chris")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                        
                        Text("James")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    CarMapView()
}
