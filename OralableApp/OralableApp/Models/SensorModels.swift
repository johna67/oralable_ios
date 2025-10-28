import Foundation

// MARK: - BLE Constants
struct BLEConstants {
    static let TGM_SERVICE = "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E"
    static let PPG_CHAR = "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E"
    static let ACC_CHAR = "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E"
    static let TEMPERATURE_CHAR = "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E"
    static let BATTERY_CHAR = "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E"
    static let UUID_CHAR = "3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E"
    static let FW_VERSION_CHAR = "3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E"
    static let MUSCLE_SITE_CHAR = "3A0FF102-98C4-46B2-94AF-1AEE0FD4C48E"
    
    static let DEVICE_NAME = "Oralable"
    static let PPG_SAMPLES_PER_FRAME = 20
    static let ACC_SAMPLES_PER_FRAME = 25
}

// MARK: - Sensor Data
struct SensorData: Codable, Equatable {
    var grinding = GrindingData()
    var accelerometer = AccelerometerData()
    var ppg = PPGData()
    var heartRate = HeartRateData()  // NEW: Heart rate data
    var temperature: Double = 0.0
    var activityLevel: UInt8 = 0
    var batteryVoltage: Int32 = 0
    var batteryLevel: UInt8 {
        let minVoltage: Int32 = 3000
        let maxVoltage: Int32 = 4200
        let percentage = Int((batteryVoltage - minVoltage) * 100 / (maxVoltage - minVoltage))
        return UInt8(max(0, min(100, percentage)))
    }
    var deviceUUID: UInt64 = 0
    var firmwareVersion: String = ""
    var timestamp: Date = Date()
}

struct GrindingData: Codable, Equatable {
    var isActive: Bool = false
    var count: UInt8 = 0
    var duration: TimeInterval = 0
    var intensity: Float = 0.0
}

struct AccelerometerData: Codable, Equatable {
    var frameCounter: UInt32 = 0
    var samples: [AccSample] = []
    
    var x: Int16 {
        return samples.last?.x ?? 0
    }
    var y: Int16 {
        return samples.last?.y ?? 0
    }
    var z: Int16 {
        return samples.last?.z ?? 0
    }
    var magnitude: Double {
        guard let last = samples.last else { return 0 }
        let dx = Double(last.x)
        let dy = Double(last.y)
        let dz = Double(last.z)
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
}

struct AccSample: Codable, Equatable {
    var x: Int16 = 0
    var y: Int16 = 0
    var z: Int16 = 0
    var timestamp: Date = Date()
}

struct PPGData: Codable, Equatable {
    var frameCounter: UInt32 = 0
    var samples: [PPGSample] = []
    
    // Use average of all samples for more stable readings
    var ir: UInt32 {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0) { $0 + $1.ir }
        return sum / UInt32(samples.count)
    }
    
    var red: UInt32 {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0) { $0 + $1.red }
        return sum / UInt32(samples.count)
    }
    
    var green: UInt32 {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0) { $0 + $1.green }
        return sum / UInt32(samples.count)
    }
    
    // Keep the old behavior available for comparison
    var lastIr: UInt32 {
        return samples.last?.ir ?? 0
    }
    var lastRed: UInt32 {
        return samples.last?.red ?? 0
    }
    var lastGreen: UInt32 {
        return samples.last?.green ?? 0
    }
}

struct PPGSample: Codable, Equatable {
    var red: UInt32 = 0
    var ir: UInt32 = 0
    var green: UInt32 = 0
    var timestamp: Date = Date()
}

// MARK: - Heart Rate Data (NEW)
struct HeartRateData: Codable, Equatable {
    var bpm: Double = 0.0
    var signalQuality: Double = 0.0  // 0.0 to 1.0
    var isValid: Bool = false
    var lastCalculated: Date = Date()
    
    /// Display text for heart rate with proper formatting
    var displayText: String {
        if isValid {
            return "\(Int(bpm)) BPM"
        } else {
            return "-- BPM"
        }
    }
    
    /// Quality level for UI display
    var qualityText: String {
        if !isValid {
            return "No Signal"
        } else if signalQuality >= 0.6 {
            return "Good"
        } else if signalQuality >= 0.3 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
    
    /// Color for quality indicator
    var qualityColor: String {
        if !isValid {
            return "gray"
        } else if signalQuality >= 0.6 {
            return "green"
        } else if signalQuality >= 0.3 {
            return "yellow"
        } else {
            return "red"
        }
    }
}

// MARK: - Measurement Sites
enum MeasurementSite: UInt8, CaseIterable, Codable {
    case masseter = 0
    case forearm = 1
    case calibration = 2
    
    var name: String {
        switch self {
        case .masseter: return "Masseter (Jaw)"
        case .forearm: return "Forearm"
        case .calibration: return "Calibration"
        }
    }
}
