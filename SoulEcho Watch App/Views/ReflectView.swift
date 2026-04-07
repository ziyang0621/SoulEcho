import SwiftUI

struct ReflectView: View {
    @State private var isBreathingIn = false
    @State private var timeRemaining = 60
    @State private var timer: Timer?
    @State private var cycleTimer: Timer?
    @State private var isActive = false
    @State private var isFinished = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            if isFinished {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    Text("冥想完成")
                        .font(.headline)
                        .padding(.top, 8)
                }
            } else {
                // Breathing Circle
                Circle()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.7), .mint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: isActive ? 140 : 80, height: isActive ? 140 : 80)
                    .scaleEffect(isBreathingIn ? 1.2 : 0.6)
                    .opacity(isBreathingIn ? 1.0 : 0.3)
                    .blur(radius: isBreathingIn ? 5 : 0)
                    .animation(.easeInOut(duration: 4.0), value: isBreathingIn)
                
                VStack {
                    Text(isActive ? (isBreathingIn ? "缓缓吸气" : "慢慢呼气") : "沉静你的心灵")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 10)
                        .animation(.easeInOut, value: isBreathingIn)
                    
                    Spacer()
                    
                    if isActive {
                        Text("\(timeRemaining)s")
                            .font(.system(.title3, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.bottom, 10)
                    } else {
                        Button(action: startReflection) {
                            Text("开始 (60秒)")
                                .bold()
                        }
                        .tint(.cyan)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopReflection()
        }
    }
    
    func startReflection() {
        isActive = true
        isBreathingIn = true // Trigger first animation
        HapticsManager.shared.playBreatheIn()
        
        // 4-second breathing cycle
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            guard isActive else { return }
            isBreathingIn.toggle()
            if isBreathingIn {
                HapticsManager.shared.playBreatheIn()
            } else {
                HapticsManager.shared.playBreatheOut()
            }
        }
        
        // 1-second countdown
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopReflection()
                isFinished = true
                HapticsManager.shared.playSuccess()
            }
        }
    }
    
    func stopReflection() {
        isActive = false
        isBreathingIn = false
        timer?.invalidate()
        cycleTimer?.invalidate()
        timer = nil
        cycleTimer = nil
    }
}

#Preview {
    ReflectView()
}
