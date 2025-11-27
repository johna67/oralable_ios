import SwiftUI

/// Manages storage and retrieval of sensor data
@MainActor
final class SensorDataStore: ObservableObject {
    @Published var latestSensorData: [String: Any] = [:]
    @Published var sensorDataHistory: [[String: Any]] = []
    
    init() {
        // Initialize sensor data store
    }
    
    func storeSensorData(_ data: [String: Any]) {
        latestSensorData = data
        sensorDataHistory.append(data)
        
        // Limit history size to prevent memory issues
        if sensorDataHistory.count > 1000 {
            sensorDataHistory.removeFirst()
        }
    }
    
    func clearHistory() {
        sensorDataHistory.removeAll()
    }
}
