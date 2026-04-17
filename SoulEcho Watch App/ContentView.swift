//
//  ContentView.swift
//  SoulEcho Watch App
//
//  Created by Ziyang Tan on 4/6/26.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var quote = ""
    @State private var author = ""
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("今日箴言")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        Text("\"\(quote)\"")
                            .font(.system(.body, design: .serif))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                            
                        Text("- \(author) -")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    NavigationLink(destination: ReflectView()) {
                        HStack {
                            Image(systemName: "lungs.fill")
                            Text("开始静心 60s")
                        }
                    }
                    }
                    .tint(.cyan)
                    .padding(.top, 10)
                }
            }
        }
        .task {
            let result = await WatchStorage.shared.fetchFreshQuote()
            quote = result.content
            author = result.author
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}
