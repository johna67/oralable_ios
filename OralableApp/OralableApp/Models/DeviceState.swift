import Foundation
import SwiftUI

/// Centralized DeviceState used across the app.
enum DeviceState: String, CaseIterable {
    case onChargerStatic = "On Charger (Static)"
    case offChargerStatic = "Off Charger (Static)"
    case inMotion = "Being Moved"
    case onCheek = "On Cheek (Masseter)"
    case unknown = "Unknown Position"

    var expectedStabilizationTime: TimeInterval {
        switch self {
        case .onChargerStatic: return 10.0
        case .offChargerStatic: return 15.0
        case .inMotion: return 30.0
        case .onCheek: return 45.0
        case .unknown: return 25.0
        }
    }

    var color: Color {
        switch self {
        case .onChargerStatic: return .green
        case .offChargerStatic: return .blue
        case .inMotion: return .orange
        case .onCheek: return .red
        case .unknown: return .gray
        }
    }

    var iconName: String {
        switch self {
        case .onChargerStatic: return "battery.100.bolt"
        case .offChargerStatic: return "battery.100"
        case .inMotion: return "figure.walk"
        case .onCheek: return "face.smiling"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Result produced by device state detection
struct DeviceStateResult {
    let state: DeviceState
    let confidence: Double // 0.0 to 1.0
    let timestamp: Date
    let details: [String: Any]

    var confidenceDescription: String {
        switch confidence {
        case 0.9...1.0: return "Very High"
        case 0.75..<0.9: return "High"
        case 0.6..<0.75: return "Moderate"
        case 0.4..<0.6: return "Low"
        default: return "Very Low"
        }
    }
}
