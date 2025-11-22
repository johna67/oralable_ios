//
//  replaces.swift
//  OralableApp
//
//  Created by John A Cogan on 22/11/2025.
//


import Foundation
import SwiftUI

/// Shared device state used across UI and processors.
/// This central enum replaces nested UI enums to avoid compile-order issues.
public enum DeviceState: String, CaseIterable, Codable {
    case onChargerStatic = "On Charger (Static)"
    case offChargerStatic = "Off Charger (Static)"
    case inMotion = "Being Moved"
    case onCheek = "On Cheek (Masseter)"
    case unknown = "Unknown Position"

    public var expectedStabilizationTime: TimeInterval {
        switch self {
        case .onChargerStatic: return 10.0
        case .offChargerStatic: return 15.0
        case .inMotion: return 30.0
        case .onCheek: return 45.0
        case .unknown: return 25.0
        }
    }

    public var color: Color {
        switch self {
        case .onChargerStatic: return .green
        case .offChargerStatic: return .blue
        case .inMotion: return .orange
        case .onCheek: return .red
        case .unknown: return .gray
        }
    }

    public var iconName: String {
        switch self {
        case .onChargerStatic: return "battery.100.bolt"
        case .offChargerStatic: return "battery.100"
        case .inMotion: return "figure.walk"
        case .onCheek: return "face.smiling"
        case .unknown: return "questionmark.circle"
        }
    }
}