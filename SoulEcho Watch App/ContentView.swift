//
//  ContentView.swift
//  SoulEcho Watch App
//
//  Created by Ziyang Tan on 4/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var quote = WatchStorage.shared.loadQuote()
    @State private var author = WatchStorage.shared.loadAuthor()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("今日箴言")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("“\(quote)”")
                        .font(.system(.body, design: .serif))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                        
                    Text("- \(author) -")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    NavigationLink(destination: ReflectView()) {
                        HStack {
                            Image(systemName: "lungs.fill")
                            Text("开始静心 60s")
                        }
                    }
                    .tint(.cyan)
                    .padding(.top, 10)
                }
            }
        }
        .onAppear {
            // Reload into memory if updated from iOS App Group
            quote = WatchStorage.shared.loadQuote()
            author = WatchStorage.shared.loadAuthor()
        }
    }
}

#Preview {
    ContentView()
}
