//
//  HealthKitManager.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Manages Apple HealthKit integration for reading and writing health data
//

import Foundation
import HealthKit
import Combine

/// Manager for Apple HealthKit integration
@MainActor
class HealthKitManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAvailable: Bool = false
    @Published var authorizationStatus: HealthKitAuthStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var latestWeight: HealthDataReading?
    @Published var recentHeartRates: [HealthDataReading] = []
    @Published var error: HealthKitError?
    
    // MARK: - Private Properties
    
    private let healthStore: HKHealthStore
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        self.healthStore = HKHealthStore()
        self.isAvailable = HKHealthStore.isHealthDataAvailable()
        
        if isAvailable {
            checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    /// Request HealthKit authorization
    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let typesToRead = HealthKitPermissions.typesToRead()
        let typesToWrite = HealthKitPermissions.typesToWrite()
        
        do {
            try await healthStore.requestAuthorization(
                toShare: typesToWrite,
                read: typesToRead
            )
            
            await checkAuthorizationStatus()
            
        } catch {
            self.error = .authorizationFailed(error.localizedDescription)
            throw HealthKitError.authorizationFailed(error.localizedDescription)
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        guard isAvailable else {
            authorizationStatus = .notDetermined
            isAuthorized = false
            return
        }
        
        // Check if we can read body mass (weight)
        if let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            let status = healthStore.authorizationStatus(for: weightType)
            
            switch status {
            case .notDetermined:
                authorizationStatus = .notDetermined
                isAuthorized = false
            case .sharingDenied:
                authorizationStatus = .denied
                isAuthorized = false
            case .sharingAuthorized:
                authorizationStatus = .authorized
                isAuthorized = true
            @unknown default:
                authorizationStatus = .restricted
                isAuthorized = false
            }
        }
    }
    
    // MARK: - Read Data
    
    /// Read latest weight from HealthKit
    func readLatestWeight() async throws -> HealthDataReading? {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidType
        }
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            
            if let error = error {
                Task { @MainActor in
                    self?.error = .readFailed(error.localizedDescription)
                }
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                return
            }
            
            let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            
            let reading = HealthDataReading(
                type: .weight,
                value: weightInKg,
                timestamp: sample.endDate,
                source: sample.sourceRevision.source.name
            )
            
            Task { @MainActor in
                self?.latestWeight = reading
            }
        }
        
        healthStore.execute(query)
        
        // Wait for query to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return latestWeight
    }
    
    /// Read heart rate samples from HealthKit
    func readHeartRateSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthDataReading] {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.readFailed(error.localizedDescription))
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let readings = samples.map { sample in
                    let bpm = sample.quantity.doubleValue(
                        for: HKUnit(from: "count/min")
                    )
                    
                    return HealthDataReading(
                        type: .heartRate,
                        value: bpm,
                        timestamp: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                }
                
                Task { @MainActor in
                    self.recentHeartRates = readings
                }
                
                continuation.resume(returning: readings)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    /// Read blood oxygen (SpO2) samples from HealthKit
    func readBloodOxygenSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthDataReading] {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            throw HealthKitError.invalidType
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: spo2Type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: HealthKitError.readFailed(error.localizedDescription))
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let readings = samples.map { sample in
                    let percentage = sample.quantity.doubleValue(
                        for: HKUnit.percent()
                    ) * 100 // Convert to percentage
                    
                    return HealthDataReading(
                        type: .bloodOxygen,
                        value: percentage,
                        timestamp: sample.endDate,
                        source: sample.sourceRevision.source.name
                    )
                }
                
                continuation.resume(returning: readings)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    /// Read all available health data
    func readAllHealthData() async throws {
        // Read weight
        _ = try await readLatestWeight()
        
        // Read heart rate from last 24 hours
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        _ = try await readHeartRateSamples(from: yesterday, to: Date())
    }
    
    // MARK: - Write Data
    
    /// Write heart rate sample to HealthKit
    func writeHeartRate(
        bpm: Double,
        timestamp: Date = Date()
    ) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidType
        }
        
        let quantity = HKQuantity(
            unit: HKUnit(from: "count/min"),
            doubleValue: bpm
        )
        
        let sample = HKQuantitySample(
            type: heartRateType,
            quantity: quantity,
            start: timestamp,
            end: timestamp,
            metadata: [
                HKMetadataKeyWasUserEntered: false,
                "Device": "Oralable"
            ]
        )
        
        try await healthStore.save(sample)
    }
    
    /// Write SpO2 sample to HealthKit
    func writeBloodOxygen(
        percentage: Double,
        timestamp: Date = Date()
    ) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            throw HealthKitError.invalidType
        }
        
        let quantity = HKQuantity(
            unit: HKUnit.percent(),
            doubleValue: percentage / 100.0 // Convert percentage to decimal
        )
        
        let sample = HKQuantitySample(
            type: spo2Type,
            quantity: quantity,
            start: timestamp,
            end: timestamp,
            metadata: [
                HKMetadataKeyWasUserEntered: false,
                "Device": "Oralable"
            ]
        )
        
        try await healthStore.save(sample)
    }
    
    /// Write sensor reading to HealthKit
    func writeSensorReading(_ reading: SensorReading) async throws {
        switch reading.sensorType {
        case .heartRate:
            try await writeHeartRate(bpm: reading.value, timestamp: reading.timestamp)
            
        case .spo2:
            try await writeBloodOxygen(percentage: reading.value, timestamp: reading.timestamp)
            
        default:
            // Other sensor types not supported for HealthKit write
            break
        }
    }
    
    /// Write multiple sensor readings to HealthKit
    func writeSensorReadings(_ readings: [SensorReading]) async throws {
        for reading in readings {
            try await writeSensorReading(reading)
        }
    }
}

// MARK: - Error Types

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case authorizationFailed(String)
    case readFailed(String)
    case writeFailed(String)
    case invalidType
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access not authorized. Please enable in Settings."
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .readFailed(let message):
            return "Failed to read data: \(message)"
        case .writeFailed(let message):
            return "Failed to write data: \(message)"
        case .invalidType:
            return "Invalid HealthKit data type"
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct HealthKitManagerPreview: View {
    
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationView {
            List {
                Section("HealthKit Status") {
                    StatusRow(
                        label: "Available",
                        value: healthKitManager.isAvailable ? "Yes" : "No",
                        color: healthKitManager.isAvailable ? DesignSystem.Colors.success : DesignSystem.Colors.error
                    )
                    
                    StatusRow(
                        label: "Authorization",
                        value: healthKitManager.authorizationStatus.displayName,
                        color: healthKitManager.isAuthorized ? DesignSystem.Colors.success : DesignSystem.Colors.warning
                    )
                }
                
                Section("Actions") {
                    Button("Request Authorization") {
                        Task {
                            try? await healthKitManager.requestAuthorization()
                        }
                    }
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Button("Read Latest Weight") {
                        Task {
                            try? await healthKitManager.readLatestWeight()
                        }
                    }
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .disabled(!healthKitManager.isAuthorized)
                    
                    Button("Read Heart Rate (24h)") {
                        Task {
                            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            try? await healthKitManager.readHeartRateSamples(from: yesterday, to: Date())
                        }
                    }
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .disabled(!healthKitManager.isAuthorized)
                    
                    Button("Write Test Heart Rate") {
                        Task {
                            try? await healthKitManager.writeHeartRate(bpm: 72)
                        }
                    }
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .disabled(!healthKitManager.isAuthorized)
                }
                
                if let weight = healthKitManager.latestWeight {
                    Section("Latest Weight") {
                        HStack {
                            Image(systemName: "scalemass")
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(weight.formattedValue)
                                    .font(DesignSystem.Typography.h3)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text(weight.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                }
                
                if !healthKitManager.recentHeartRates.isEmpty {
                    Section("Recent Heart Rates") {
                        ForEach(healthKitManager.recentHeartRates.prefix(5)) { reading in
                            HStack {
                                Text(reading.formattedValue)
                                    .font(DesignSystem.Typography.bodyMedium)
                                
                                Spacer()
                                
                                Text(reading.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                }
                
                if let error = healthKitManager.error {
                    Section("Error") {
                        Text(error.localizedDescription)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.error)
                    }
                }
            }
            .navigationTitle("HealthKit Manager")
            .background(DesignSystem.Colors.backgroundPrimary)
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(color)
        }
    }
}

struct HealthKitManager_Previews: PreviewProvider {
    static var previews: some View {
        HealthKitManagerPreview()
    }
}

#endif
