//
//  ContentView.swift
//  SoulEcho
//
//  Created by Ziyang Tan on 4/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            HomeView()
                .opacity(showSplash ? 0 : 1)
            
            if showSplash {
                SplashView(showSplash: $showSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}

struct SplashView: View {
    @Binding var showSplash: Bool
    
    @State private var opacity = 0.0
    @State private var logoScale = 0.8
    
    var body: some View {
        ZStack {
            // Background matching the white-gold theme
            LinearGradient(colors: [Color(hex: "FFFFFF"), Color(hex: "F8F6F0"), Color(hex: "DCCA87")],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Geometric simple abstract star/sparkle representing "SoulEcho"
                Image(systemName: "sparkles")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(Color(hex: "8C7221"))
                    .scaleEffect(logoScale)
                
                Text("SoulEcho")
                    .font(.system(size: 36, weight: .thin, design: .serif))
                    .foregroundColor(Color(hex: "3B3012"))
                    .tracking(8) // elegant spacing
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                opacity = 1.0
                logoScale = 1.0
            }
            
            // Dispatch the hide directly from the child component
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
