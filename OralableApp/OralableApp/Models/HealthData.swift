//
//  HealthData.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Models for Apple HealthKit data integration
//

import Foundation
import HealthKit

/// Health data types that can be read from HealthKit
enum HealthDataType: String, Codable, CaseIterable {
    case weight
    case heartRate
    case bloodOxygen
    case sleepAnalysis
    case workouts
    case respiratoryRate
    
    var displayName: String {
        switch self {
        case .weight:
            return "Weight"
        case .heartRate:
            return "Heart Rate"
        case .bloodOxygen:
            return "Blood Oxygen"
        case .sleepAnalysis:
            return "Sleep"
        case .workouts:
            return "Workouts"
        case .respiratoryRate:
            return "Respiratory Rate"
        }
    }
    
    var unit: String {
        switch self {
        case .weight:
            return "kg"
        case .heartRate:
            return "bpm"
        case .bloodOxygen:
            return "%"
        case .sleepAnalysis:
            return "hours"
        case .workouts:
            return "minutes"
        case .respiratoryRate:
            return "breaths/min"
        }
    }
    
    var iconName: String {
        switch self {
        case .weight:
            return "scalemass"
        case .heartRate:
            return "heart.fill"
        case .bloodOxygen:
            return "lungs.fill"
        case .sleepAnalysis:
            return "bed.double.fill"
        case .workouts:
            return "figure.run"
        case .respiratoryRate:
            return "wind"
        }
    }
    
    /// Convert to HKQuantityTypeIdentifier
    var quantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .weight:
            return .bodyMass
        case .heartRate:
            return .heartRate
        case .bloodOxygen:
            return .oxygenSaturation
        case .respiratoryRate:
            return .respiratoryRate
        case .sleepAnalysis, .workouts:
            return nil
        }
    }
    
    /// Convert to HKCategoryTypeIdentifier
    var categoryTypeIdentifier: HKCategoryTypeIdentifier? {
        switch self {
        case .sleepAnalysis:
            return .sleepAnalysis
        default:
            return nil
        }
    }
}

/// Unified health data reading from HealthKit
struct HealthDataReading: Identifiable, Codable {
    
    let id: UUID
    let type: HealthDataType
    let value: Double
    let timestamp: Date
    let source: String?
    
    init(
        id: UUID = UUID(),
        type: HealthDataType,
        value: Double,
        timestamp: Date = Date(),
        source: String? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.timestamp = timestamp
        self.source = source
    }
    
    /// Formatted value with unit
    var formattedValue: String {
        switch type {
        case .weight:
            return String(format: "%.1f %@", value, type.unit)
        case .heartRate, .bloodOxygen, .respiratoryRate:
            return String(format: "%.0f %@", value, type.unit)
        case .sleepAnalysis, .workouts:
            return String(format: "%.1f %@", value, type.unit)
        }
    }
    
    /// Create mock reading for testing
    static func mock(type: HealthDataType) -> HealthDataReading {
        let value: Double = {
            switch type {
            case .weight: return 75.5
            case .heartRate: return 72
            case .bloodOxygen: return 98
            case .sleepAnalysis: return 7.5
            case .workouts: return 45
            case .respiratoryRate: return 16
            }
        }()
        
        return HealthDataReading(
            type: type,
            value: value,
            source: "Apple Health"
        )
    }
}

/// HealthKit authorization status
enum HealthKitAuthStatus: String, Codable {
    case notDetermined
    case denied
    case authorized
    case restricted
    
    var displayName: String {
        switch self {
        case .notDetermined:
            return "Not Set"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .restricted:
            return "Restricted"
        }
    }
    
    var canRead: Bool {
        self == .authorized
    }
    
    var canWrite: Bool {
        self == .authorized
    }
}

/// HealthKit permissions configuration
struct HealthKitPermissions {
    
    // Types to read
    static let readTypes: Set<HealthDataType> = [
        .weight,
        .heartRate,
        .bloodOxygen,
        .sleepAnalysis,
        .workouts,
        .respiratoryRate
    ]
    
    // Types to write
    static let writeTypes: Set<HealthDataType> = [
        .heartRate,
        .bloodOxygen
    ]
    
    /// Get HKObjectTypes for reading
    static func typesToRead() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        for dataType in readTypes {
            if let quantityType = dataType.quantityTypeIdentifier {
                if let type = HKObjectType.quantityType(forIdentifier: quantityType) {
                    types.insert(type)
                }
            }
            
            if let categoryType = dataType.categoryTypeIdentifier {
                if let type = HKObjectType.categoryType(forIdentifier: categoryType) {
                    types.insert(type)
                }
            }
        }
        
        // Add workout type
        types.insert(HKObjectType.workoutType())
        
        return types
    }
    
    /// Get HKSampleTypes for writing
    static func typesToWrite() -> Set<HKSampleType> {
        var types = Set<HKSampleType>()
        
        for dataType in writeTypes {
            if let quantityType = dataType.quantityTypeIdentifier {
                if let type = HKObjectType.quantityType(forIdentifier: quantityType) {
                    types.insert(type)
                }
            }
        }
        
        return types
    }
}

// MARK: - Array Extensions

extension Array where Element == HealthDataReading {
    
    /// Get latest reading for a type
    func latest(for type: HealthDataType) -> HealthDataReading? {
        self
            .filter { $0.type == type }
            .max { $0.timestamp < $1.timestamp }
    }
    
    /// Get readings within date range
    func readings(
        for type: HealthDataType,
        from startDate: Date,
        to endDate: Date
    ) -> [HealthDataReading] {
        self.filter {
            $0.type == type &&
            $0.timestamp >= startDate &&
            $0.timestamp <= endDate
        }
    }
    
    /// Calculate average for a type
    func average(for type: HealthDataType) -> Double? {
        let readings = self.filter { $0.type == type }
        guard !readings.isEmpty else { return nil }
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct HealthDataPreview: View {
    
    let readings: [HealthDataReading] = HealthDataType.allCases.map { .mock(type: $0) }
    
    var body: some View {
        NavigationView {
            List {
                Section("Available Health Data") {
                    ForEach(readings) { reading in
                        HStack {
                            Image(systemName: reading.type.iconName)
                                .font(.system(size: DesignSystem.Sizing.Icon.lg))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reading.type.displayName)
                                    .font(DesignSystem.Typography.bodyLarge)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                if let source = reading.source {
                                    Text("Source: \(source)")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(reading.formattedValue)
                                .font(DesignSystem.Typography.labelLarge)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                }
                
                Section("Permissions") {
                    ForEach(HealthDataType.allCases, id: \.self) { type in
                        HStack {
                            Text(type.displayName)
                                .font(DesignSystem.Typography.bodyMedium)
                            
                            Spacer()
                            
                            if HealthKitPermissions.readTypes.contains(type) {
                                Image(systemName: "book.fill")
                                    .font(.system(size: DesignSystem.Sizing.Icon.sm))
                                    .foregroundColor(DesignSystem.Colors.info)
                            }
                            
                            if HealthKitPermissions.writeTypes.contains(type) {
                                Image(systemName: "pencil")
                                    .font(.system(size: DesignSystem.Sizing.Icon.sm))
                                    .foregroundColor(DesignSystem.Colors.success)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Health Data")
            .background(DesignSystem.Colors.backgroundPrimary)
        }
    }
}

struct HealthData_Previews: PreviewProvider {
    static var previews: some View {
        HealthDataPreview()
    }
}

#endif
