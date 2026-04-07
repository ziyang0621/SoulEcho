import WatchKit

class HapticsManager {
    static let shared = HapticsManager()
    
    func playBreatheIn() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    func playBreatheOut() {
        WKInterfaceDevice.current().play(.directionDown)
    }
    
    func playSuccess() {
        WKInterfaceDevice.current().play(.success)
    }
}
