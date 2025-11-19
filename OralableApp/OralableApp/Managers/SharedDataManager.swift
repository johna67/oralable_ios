import Foundation
import CloudKit

// MARK: - Shared Data Models

struct SharedPatientData: Identifiable {
    let id: UUID
    let patientID: String          // Anonymized patient identifier
    let dentistID: String          // Dentist's Apple ID
    let shareCode: String          // 6-digit share code
    let accessGrantedDate: Date
    let expiryDate: Date?          // Optional time limit
    let permissions: SharePermission
    let isActive: Bool

    init(patientID: String, dentistID: String, shareCode: String, permissions: SharePermission = .readOnly, expiryDate: Date? = nil) {
        self.id = UUID()
        self.patientID = patientID
        self.dentistID = dentistID
        self.shareCode = shareCode
        self.accessGrantedDate = Date()
        self.expiryDate = expiryDate
        self.permissions = permissions
        self.isActive = true
    }
}

enum SharePermission: String, Codable {
    case readOnly = "read_only"
    case readWrite = "read_write"  // Future use
}

struct SharedDentist: Identifiable {
    let id: String
    let dentistID: String
    let dentistName: String?
    let sharedDate: Date
    let expiryDate: Date?
    let isActive: Bool
}

// MARK: - Shared Data Manager

@MainActor
class SharedDataManager: ObservableObject {
    @Published var sharedDentists: [SharedDentist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let authenticationManager: AuthenticationManager
    private let healthKitManager: HealthKitManager
    private weak var bleManager: OralableBLE?

    init(authenticationManager: AuthenticationManager, healthKitManager: HealthKitManager, bleManager: OralableBLE? = nil) {
        // Use shared container for both patient and dentist apps
        self.container = CKContainer(identifier: "iCloud.com.jacdental.oralable.shared")
        self.publicDatabase = container.publicCloudDatabase

        // Store reference to authentication manager
        self.authenticationManager = authenticationManager

        // Store reference to HealthKit manager
        self.healthKitManager = healthKitManager

        // Store reference to BLE manager for sensor data access
        self.bleManager = bleManager

        loadSharedDentists()
    }

    // Computed property for backward compatibility
    private var userID: String? {
        return authenticationManager.userID
    }

    // MARK: - Patient Side: Generate Share Code

    func generateShareCode() -> String {
        // Generate 6-digit code
        let code = String(format: "%06d", Int.random(in: 0...999999))
        return code
    }

    func createShareInvitation() async throws -> String {
        guard let patientID = userID else {
            throw ShareError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        let shareCode = generateShareCode()

        // Create CloudKit record
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "ShareInvitation", recordID: recordID)

        record["patientID"] = patientID as CKRecordValue
        record["shareCode"] = shareCode as CKRecordValue
        record["createdDate"] = Date() as CKRecordValue
        record["expiryDate"] = Calendar.current.date(byAdding: .hour, value: 48, to: Date()) as CKRecordValue?
        record["isActive"] = 1 as CKRecordValue
        record["dentistID"] = "" as CKRecordValue  // Will be filled when dentist enters code

        do {
            try await publicDatabase.save(record)
            isLoading = false
            return shareCode
        } catch {
            isLoading = false
            errorMessage = "Failed to create share invitation: \(error.localizedDescription)"
            throw ShareError.cloudKitError(error)
        }
    }

    func revokeAccessForDentist(dentistID: String) async throws {
        guard let patientID = userID else {
            throw ShareError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        // Query for the share record
        let predicate = NSPredicate(format: "patientID == %@ AND dentistID == %@", patientID, dentistID)
        let query = CKQuery(recordType: "SharedPatientData", predicate: predicate)

        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query)

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    // Mark as inactive
                    record["isActive"] = 0 as CKRecordValue
                    try await publicDatabase.save(record)
                case .failure(let error):
                    Logger.shared.error("[SharedDataManager] Error fetching record: \(error)")
                }
            }

            // Reload shared dentists
            await loadSharedDentists()

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to revoke access: \(error.localizedDescription)"
            throw ShareError.cloudKitError(error)
        }
    }

    func loadSharedDentists() {
        guard let patientID = userID else { return }

        Task {
            isLoading = true

            let predicate = NSPredicate(format: "patientID == %@ AND isActive == 1", patientID)
            let query = CKQuery(recordType: "SharedPatientData", predicate: predicate)

            do {
                let (matchResults, _) = try await publicDatabase.records(matching: query)

                var dentists: [SharedDentist] = []
                for (_, result) in matchResults {
                    switch result {
                    case .success(let record):
                        if let dentistID = record["dentistID"] as? String,
                           let sharedDate = record["accessGrantedDate"] as? Date {
                            let dentist = SharedDentist(
                                id: record.recordID.recordName,
                                dentistID: dentistID,
                                dentistName: record["dentistName"] as? String,
                                sharedDate: sharedDate,
                                expiryDate: record["expiryDate"] as? Date,
                                isActive: (record["isActive"] as? Int) == 1
                            )
                            dentists.append(dentist)
                        }
                    case .failure(let error):
                        Logger.shared.error("[SharedDataManager] Error loading dentist: \(error)")
                    }
                }

                await MainActor.run {
                    self.sharedDentists = dentists
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load shared dentists: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Get Patient Health Data for Sharing

    func getPatientHealthDataForSharing(from startDate: Date, to endDate: Date) async throws -> [HealthDataRecord] {
        // Fetch HealthKit data if authorized
        var healthKitData: HealthKitDataForSharing? = nil

        if healthKitManager.isAuthorized {
            do {
                // Fetch heart rate data
                let heartRateReadings = try await healthKitManager.readHeartRateSamples(
                    from: startDate,
                    to: endDate
                )

                // Fetch SpO2 data
                let spo2Readings = try await healthKitManager.readBloodOxygenSamples(
                    from: startDate,
                    to: endDate
                )

                // Create HealthKit data package
                healthKitData = HealthKitDataForSharing(
                    heartRateReadings: heartRateReadings,
                    spo2Readings: spo2Readings,
                    sleepData: nil  // Sleep data can be added later if needed
                )

                Logger.shared.info("[SharedDataManager] Fetched HealthKit data: \(heartRateReadings.count) HR readings, \(spo2Readings.count) SpO2 readings")
            } catch {
                Logger.shared.error("[SharedDataManager] Failed to fetch HealthKit data: \(error)")
                // Continue without HealthKit data - don't fail the entire share
            }
        }

        // Fetch bruxism sensor data from local storage
        var measurements = Data()
        var recordingDate = startDate
        var actualDataCount = 0

        if let ble = bleManager {
            do {
                // Filter sensor data to the requested time range
                let filteredData = ble.sensorDataHistory.filter {
                    $0.timestamp >= startDate && $0.timestamp <= endDate
                }

                if !filteredData.isEmpty {
                    // Create serializable bruxism session data
                    let sessionData = BruxismSessionData(sensorData: filteredData)

                    // Serialize to Data
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    measurements = try encoder.encode(sessionData)

                    // Use the earliest timestamp as recording date
                    recordingDate = filteredData.first?.timestamp ?? startDate
                    actualDataCount = filteredData.count

                    Logger.shared.info("[SharedDataManager] Serialized \(filteredData.count) sensor readings for sharing (\(measurements.count) bytes)")
                } else {
                    Logger.shared.warning("[SharedDataManager] No sensor data available for time range \(startDate) to \(endDate)")
                }
            } catch {
                Logger.shared.error("[SharedDataManager] Failed to serialize sensor data: \(error)")
                // Continue with empty measurements - don't fail the entire share
            }
        } else {
            Logger.shared.warning("[SharedDataManager] BLE manager not available, sharing without sensor data")
        }

        let record = HealthDataRecord(
            recordID: UUID().uuidString,
            recordingDate: recordingDate,
            dataType: "bruxism_session",
            measurements: measurements,
            sessionDuration: endDate.timeIntervalSince(startDate),
            healthKitData: healthKitData
        )

        return [record]
    }

    /// Fetch HealthKit data for a specific time period
    func fetchHealthKitData(from startDate: Date, to endDate: Date) async throws -> HealthKitDataForSharing? {
        guard healthKitManager.isAuthorized else {
            return nil
        }

        let heartRateReadings = try await healthKitManager.readHeartRateSamples(
            from: startDate,
            to: endDate
        )

        let spo2Readings = try await healthKitManager.readBloodOxygenSamples(
            from: startDate,
            to: endDate
        )

        return HealthKitDataForSharing(
            heartRateReadings: heartRateReadings,
            spo2Readings: spo2Readings,
            sleepData: nil
        )
    }
}

// MARK: - Share Errors

enum ShareError: LocalizedError {
    case notAuthenticated
    case cloudKitError(Error)
    case invalidShareCode
    case shareCodeExpired
    case dentistNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to share data"
        case .cloudKitError(let error):
            return "Cloud error: \(error.localizedDescription)"
        case .invalidShareCode:
            return "Invalid share code"
        case .shareCodeExpired:
            return "Share code has expired"
        case .dentistNotFound:
            return "Dentist not found"
        }
    }
}

// MARK: - Health Data Record (for sharing)

struct HealthDataRecord: Codable {
    let recordID: String
    let recordingDate: Date
    let dataType: String
    let measurements: Data
    let sessionDuration: TimeInterval
    let healthKitData: HealthKitDataForSharing?  // NEW: Include HealthKit data
}

// MARK: - HealthKit Data for Sharing

struct HealthKitDataForSharing: Codable {
    let heartRateReadings: [HealthDataReading]
    let spo2Readings: [HealthDataReading]
    let sleepData: [SleepDataPoint]?

    var averageHeartRate: Double? {
        guard !heartRateReadings.isEmpty else { return nil }
        return heartRateReadings.reduce(0.0) { $0 + $1.value } / Double(heartRateReadings.count)
    }

    var averageSpO2: Double? {
        guard !spo2Readings.isEmpty else { return nil }
        return spo2Readings.reduce(0.0) { $0 + $1.value } / Double(spo2Readings.count)
    }
}

struct SleepDataPoint: Codable {
    let startDate: Date
    let endDate: Date
    let sleepStage: String  // "deep", "light", "rem", "awake"
}

// MARK: - Bruxism Session Data (for sharing sensor data)

/// Serializable structure containing bruxism sensor data for sharing with dentists
struct BruxismSessionData: Codable {
    let sensorReadings: [SerializableSensorData]
    let recordingCount: Int
    let startDate: Date
    let endDate: Date

    init(sensorData: [SensorData]) {
        self.sensorReadings = sensorData.map { SerializableSensorData(from: $0) }
        self.recordingCount = sensorData.count
        self.startDate = sensorData.first?.timestamp ?? Date()
        self.endDate = sensorData.last?.timestamp ?? Date()
    }
}

/// Simplified sensor data structure for serialization
struct SerializableSensorData: Codable {
    let timestamp: Date

    // PPG data
    let ppgRed: Int32
    let ppgIR: Int32
    let ppgGreen: Int32

    // Accelerometer data
    let accelX: Int16
    let accelY: Int16
    let accelZ: Int16
    let accelMagnitude: Double

    // Temperature
    let temperatureCelsius: Double

    // Battery
    let batteryPercentage: Int

    // Calculated metrics
    let heartRateBPM: Double?
    let heartRateQuality: Double?
    let spo2Percentage: Double?
    let spo2Quality: Double?

    init(from sensorData: SensorData) {
        self.timestamp = sensorData.timestamp

        // PPG data
        self.ppgRed = sensorData.ppg.red
        self.ppgIR = sensorData.ppg.ir
        self.ppgGreen = sensorData.ppg.green

        // Accelerometer data
        self.accelX = sensorData.accelerometer.x
        self.accelY = sensorData.accelerometer.y
        self.accelZ = sensorData.accelerometer.z
        self.accelMagnitude = sensorData.accelerometer.magnitude

        // Temperature
        self.temperatureCelsius = sensorData.temperature.celsius

        // Battery
        self.batteryPercentage = sensorData.battery.percentage

        // Calculated metrics
        self.heartRateBPM = sensorData.heartRate?.bpm
        self.heartRateQuality = sensorData.heartRate?.quality
        self.spo2Percentage = sensorData.spo2?.percentage
        self.spo2Quality = sensorData.spo2?.quality
    }
}
