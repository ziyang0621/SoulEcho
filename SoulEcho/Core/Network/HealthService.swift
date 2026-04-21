import Foundation
import HealthKit
import Observation

@Observable
class HealthService {
    var hrvValue: Double?
    var hrvTimestamp: Date?
    var isLoading = false
    
    private let healthStore = HKHealthStore()
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    
    func requestAuthorizationAndFetch() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [hrvType])
            await fetchLatestHRV()
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }
    
    func fetchLatestHRV() async {
        isLoading = true
        defer { isLoading = false }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample, error == nil else {
                return
            }
            
            let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            
            DispatchQueue.main.async {
                self?.hrvValue = value
                self?.hrvTimestamp = sample.endDate
            }
        }
        
        healthStore.execute(query)
    }
    
    var hrvStatusText: String {
        guard let hrv = hrvValue else { return "" }
        if hrv >= 60 {
            return String(localized: "身心放松 ✨")
        } else if hrv >= 40 {
            return String(localized: "状态一般 💛")
        } else {
            return String(localized: "压力偏高 🧘")
        }
    }
    
    var hrvColorName: String {
        guard let hrv = hrvValue else { return "8C7221" } // Fallback to gold
        if hrv >= 60 { return "27AE60" } // Green
        if hrv >= 40 { return "F1C40F" } // Yellow
        return "E74C3C" // Red
    }
}
