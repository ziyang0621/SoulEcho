import SwiftUI

struct HomeView: View {
    @State private var quoteService = QuoteService()
    @State private var weatherService = WeatherService()
    @State private var healthService = HealthService()
    @State private var animateGradient = false
    @State private var quoteScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Animated Gradient Background - White & Gold Theme
            LinearGradient(colors: [Color(hex: "FFFFFF"), Color(hex: "F8F6F0"), Color(hex: "DCCA87")],
                           startPoint: animateGradient ? .topLeading : .bottomLeading,
                           endPoint: animateGradient ? .bottomTrailing : .topTrailing)
                 .ignoresSafeArea()
                 .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: animateGradient)
                 .onAppear {
                     animateGradient.toggle()
                 }
             
             VStack(spacing: 30) {
                 Spacer()
                 
                 // Quote Section
                 if quoteService.isLoading {
                     ProgressView()
                         .tint(Color(hex: "BFA054"))
                 } else if let quote = quoteService.currentQuote {
                     VStack(spacing: 20) {
                         Text("“\(quote.content)”")
                             .font(.system(size: 28, weight: .semibold, design: .serif))
                             .foregroundColor(Color(hex: "3B3012"))
                             .multilineTextAlignment(.center)
                             .lineSpacing(8)
                             .shadow(color: .white.opacity(0.5), radius: 5, x: 0, y: 2)
                             .padding(.horizontal, 20)
                         
                         Text("- \(quote.author) -")
                             .font(.system(size: 18, weight: .medium, design: .serif))
                             .foregroundColor(Color(hex: "5A4C2E"))
                     }
                     .scaleEffect(quoteScale)
                     .onTapGesture {
                         withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                             quoteScale = 0.95
                         }
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                             withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                 quoteScale = 1.0
                             }
                         }
                     }
                 }
                 
                 Spacer()
                 
                 VStack(spacing: 16) {
                     // HRV Status Card
                     if let hrv = healthService.hrvValue {
                         VStack(alignment: .leading, spacing: 12) {
                             HStack {
                                 Image(systemName: "heart.text.square.fill")
                                     .foregroundColor(Color(hex: healthService.hrvColorName))
                                     .font(.title2)
                                 
                                 Text("HRV数据")
                                     .font(.system(size: 14, weight: .bold))
                                     .foregroundColor(Color(hex: "5A4C2E").opacity(0.8))
                                 
                                 Spacer()
                                 
                                 Text("\(Int(hrv)) ms")
                                     .font(.system(size: 24, weight: .bold, design: .rounded))
                                     .foregroundColor(Color(hex: healthService.hrvColorName))
                             }
                             
                             HStack {
                                 Text(healthService.hrvStatusText)
                                     .font(.system(size: 16, weight: .semibold))
                                     .foregroundColor(Color(hex: "3B3012"))
                                 
                                 Spacer()
                                 
                                 if let timestamp = healthService.hrvTimestamp {
                                     let isEnglish = Locale.current.language.languageCode?.identifier != "zh"
                                     
                                     Group {
                                         if isEnglish {
                                             Text("上次更新")
                                         }
                                         
                                         Text(timestamp, style: .relative)
                                         
                                         if !isEnglish {
                                             Text("前更新")
                                         } else {
                                             Text("前更新")
                                         }
                                     }
                                     .font(.system(size: 12))
                                     .foregroundColor(Color(hex: "5A4C2E").opacity(0.6))
                                 }
                             }
                         }
                         .padding(20)
                         .background(Color.white.opacity(0.3))
                         .background(.ultraThinMaterial)
                         .cornerRadius(20)
                         .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                         .padding(.horizontal, 24)
                     }
                     
                     // Weather Recommendation Card
                     if let recommendation = weatherService.recommendation {
                         HStack(spacing: 16) {
                             Image(systemName: recommendation.isSuitableForOutdoor ? "leaf.fill" : "house.fill")
                                 .font(.system(size: 24))
                                 .foregroundColor(Color(hex: "8C7221"))
                             
                             Text(recommendation.message)
                                 .font(.system(size: 16, weight: .medium))
                                 .foregroundColor(Color(hex: "3B3012").opacity(0.9))
                                 .multilineTextAlignment(.leading)
                         }
                         .frame(maxWidth: .infinity, alignment: .leading)
                         .padding(20)
                         .background(Color.white.opacity(0.3))
                         .background(.ultraThinMaterial)
                         .cornerRadius(20)
                         .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                         .padding(.horizontal, 24)
                     } else if weatherService.isLoading {
                         ProgressView()
                             .tint(Color(hex: "BFA054"))
                     }
                 }
                 
                 Spacer().frame(height: 40)
             }
         }
         .task {
             await quoteService.fetchTodayQuote()
             await weatherService.fetchWeatherRecommendation()
             await healthService.requestAuthorizationAndFetch()
         }
     }
 }

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

#Preview {
    HomeView()
}
