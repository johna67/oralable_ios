import Foundation
import CloudKit
import Combine

// MARK: - Patient Models

struct DentistPatient: Identifiable, Codable {
    let id: String
    let patientID: String
    let patientName: String?  // Optional - patient may choose anonymity
    let shareCode: String
    let accessGrantedDate: Date
    let lastDataUpdate: Date?
    let recordID: String  // CloudKit record ID

    var anonymizedID: String {
        // Show only last 4 characters of patient ID for privacy
        let suffix = String(patientID.suffix(4))
        return "Patient-****\(suffix)"
    }

    var displayName: String {
        return patientName ?? anonymizedID
    }
}

struct PatientHealthSummary {
    let patientID: String
    let recordingDate: Date
    let sessionDuration: TimeInterval
    let bruxismEvents: Int
    let averageIntensity: Double
    let peakIntensity: Double
    let heartRateData: [Double]
    let oxygenSaturation: [Double]

    var formattedDuration: String {
        let hours = Int(sessionDuration) / 3600
        let minutes = Int(sessionDuration) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Dentist Data Manager

@MainActor
class DentistDataManager: ObservableObject {
    static let shared = DentistDataManager()

    // MARK: - Published Properties

    @Published var patients: [DentistPatient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Private Properties

    private let container: CKContainer
    private let publicDatabase: CKDatabase

    // Computed property that reads from Keychain (where DentistAuthenticationManager stores it)
    private var dentistID: String? {
        // Read from Keychain using the same key as DentistAuthenticationManager
        let keychainKey = "com.oralable.dentist.userID"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let userID = String(data: data, encoding: .utf8) {
            return userID
        }

        // Fallback: check UserDefaults for migration (legacy support)
        return UserDefaults.standard.string(forKey: "dentistAppleID")
    }

    // MARK: - Initialization

    private init() {
        // Use same shared container as patient app
        self.container = CKContainer(identifier: "iCloud.com.jacdental.oralable.shared")

        // For development/testing, use private database which auto-creates schemas
        // In production, switch to publicCloudDatabase after setting up schema
#if DEBUG
self.publicDatabase = container.privateCloudDatabase
#else
self.publicDatabase = container.publicCloudDatabase
#endif
        // Load existing patients when initialized
        loadPatients()
    }

    // MARK: - Share Code Entry

    func addPatientWithShareCode(_ shareCode: String) async throws {
        guard let dentistID = dentistID else {
            throw DentistDataError.notAuthenticated
        }

        // Validate share code format (6 digits)
        guard shareCode.count == 6, Int(shareCode) != nil else {
            throw DentistDataError.invalidShareCode
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            // Step 1: Find the share invitation with this code
            let predicate = NSPredicate(format: "shareCode == %@ AND isActive == 1", shareCode)
            let query = CKQuery(recordType: "ShareInvitation", predicate: predicate)

            let (matchResults, _) = try await publicDatabase.records(matching: query)

            guard let (_, result) = matchResults.first else {
                throw DentistDataError.shareCodeNotFound
            }

            guard case .success(let invitationRecord) = result else {
                throw DentistDataError.shareCodeNotFound
            }

            // Step 2: Check if code is expired
            if let expiryDate = invitationRecord["expiryDate"] as? Date,
               expiryDate < Date() {
                throw DentistDataError.shareCodeExpired
            }

            // Step 3: Get patient ID from invitation
            guard let patientID = invitationRecord["patientID"] as? String else {
                throw DentistDataError.invalidShareCode
            }

            // Step 4: Check if dentist already has access to this patient
            if patients.contains(where: { $0.patientID == patientID }) {
                throw DentistDataError.patientAlreadyAdded
            }

            // Step 5: Create SharedPatientData record
            let sharedDataID = CKRecord.ID(recordName: UUID().uuidString)
            let sharedDataRecord = CKRecord(recordType: "SharedPatientData", recordID: sharedDataID)

            sharedDataRecord["patientID"] = patientID as CKRecordValue
            sharedDataRecord["dentistID"] = dentistID as CKRecordValue
            sharedDataRecord["shareCode"] = shareCode as CKRecordValue
            sharedDataRecord["accessGrantedDate"] = Date() as CKRecordValue
            sharedDataRecord["isActive"] = 1 as CKRecordValue
            sharedDataRecord["dentistName"] = getCurrentDentistName() as CKRecordValue?

            try await publicDatabase.save(sharedDataRecord)

            // Step 6: Update the invitation to mark it as used
            invitationRecord["dentistID"] = dentistID as CKRecordValue
            invitationRecord["isActive"] = 0 as CKRecordValue
            try await publicDatabase.save(invitationRecord)

            // Step 7: Add to local patient list
            let newPatient = DentistPatient(
                id: sharedDataID.recordName,
                patientID: patientID,
                patientName: nil,  // Will be updated if patient provides name
                shareCode: shareCode,
                accessGrantedDate: Date(),
                lastDataUpdate: nil,
                recordID: sharedDataID.recordName
            )

            await MainActor.run {
                self.patients.append(newPatient)
                self.isLoading = false
                self.successMessage = "Patient added successfully"
            }

        } catch let error as DentistDataError {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to add patient: \(error.localizedDescription)"
            }
            throw error
        }
    }

    // MARK: - Patient Management

    func loadPatients() {
        guard let dentistID = dentistID else { return }

        Task {
            isLoading = true
            errorMessage = nil

            let predicate = NSPredicate(format: "dentistID == %@ AND isActive == 1", dentistID)
            let query = CKQuery(recordType: "SharedPatientData", predicate: predicate)

            do {
                let (matchResults, _) = try await publicDatabase.records(matching: query)

                var loadedPatients: [DentistPatient] = []

                for (_, result) in matchResults {
                    switch result {
                    case .success(let record):
                        if let patientID = record["patientID"] as? String,
                           let shareCode = record["shareCode"] as? String,
                           let accessDate = record["accessGrantedDate"] as? Date {

                            let patient = DentistPatient(
                                id: record.recordID.recordName,
                                patientID: patientID,
                                patientName: record["patientName"] as? String,
                                shareCode: shareCode,
                                accessGrantedDate: accessDate,
                                lastDataUpdate: record["lastDataUpdate"] as? Date,
                                recordID: record.recordID.recordName
                            )

                            loadedPatients.append(patient)
                        }
                    case .failure(let error):
                        Logger.shared.error("[DentistDataManager] Error loading patient record: \(error)")
                    }
                }

                await MainActor.run {
                    self.patients = loadedPatients.sorted { $0.accessGrantedDate > $1.accessGrantedDate }
                    self.isLoading = false
                }

            } catch {
                // Check if this is a "record type not found" error
                // This happens when no patients have been added yet in Development mode
                let nsError = error as NSError
                if nsError.domain == CKErrorDomain && nsError.code == CKError.unknownItem.rawValue {
                    Logger.shared.info("[DentistDataManager] Record type doesn't exist yet - no patients have been added")
                    await MainActor.run {
                        self.patients = []
                        self.isLoading = false
                    }
                } else {
                    Logger.shared.error("[DentistDataManager] Failed to load patients: \(error)")
                    await MainActor.run {
                        self.errorMessage = "Failed to load patients: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
        }
    }

    func removePatient(_ patient: DentistPatient) async throws {
        isLoading = true
        errorMessage = nil

        do {
            // Find and update the SharedPatientData record
            let recordID = CKRecord.ID(recordName: patient.recordID)
            let record = try await publicDatabase.record(for: recordID)

            record["isActive"] = 0 as CKRecordValue
            try await publicDatabase.save(record)

            await MainActor.run {
                self.patients.removeAll { $0.id == patient.id }
                self.isLoading = false
                self.successMessage = "Patient removed"
            }

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to remove patient: \(error.localizedDescription)"
            }
            throw error
        }
    }

    // MARK: - Patient Data Fetching

    func fetchPatientHealthData(for patient: DentistPatient, from startDate: Date, to endDate: Date) async throws -> [PatientHealthSummary] {
        isLoading = true
        errorMessage = nil

        do {
            // Query HealthDataRecord CloudKit records for this patient
            let predicate = NSPredicate(
                format: "patientID == %@ AND recordingDate >= %@ AND recordingDate <= %@",
                patient.patientID,
                startDate as NSDate,
                endDate as NSDate
            )
            let query = CKQuery(recordType: "HealthDataRecord", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "recordingDate", ascending: false)]

            let (matchResults, _) = try await publicDatabase.records(matching: query)

            var healthSummaries: [PatientHealthSummary] = []

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    // Parse health data from record
                    // This is a simplified example - actual implementation would parse sensor data
                    if let recordDate = record["recordingDate"] as? Date,
                       let duration = record["sessionDuration"] as? Double {

                        let summary = PatientHealthSummary(
                            patientID: patient.patientID,
                            recordingDate: recordDate,
                            sessionDuration: duration,
                            bruxismEvents: record["bruxismEvents"] as? Int ?? 0,
                            averageIntensity: record["averageIntensity"] as? Double ?? 0.0,
                            peakIntensity: record["peakIntensity"] as? Double ?? 0.0,
                            heartRateData: [],  // Would parse from measurements data
                            oxygenSaturation: []  // Would parse from measurements data
                        )

                        healthSummaries.append(summary)
                    }
                case .failure(let error):
                    Logger.shared.error("[DentistDataManager] Error loading health record: \(error)")
                }
            }

            await MainActor.run {
                self.isLoading = false
            }

            return healthSummaries

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load patient data: \(error.localizedDescription)"
            }
            throw error
        }
    }

    // MARK: - Fetch Sensor Time-Series Data

    /// Fetch detailed sensor data for a patient session (for time-series charts)
    func fetchPatientSensorData(for patient: DentistPatient, sessionDate: Date) async throws -> BruxismSessionData? {
        isLoading = true
        errorMessage = nil

        do {
            // Query for the specific session
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: sessionDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let predicate = NSPredicate(
                format: "patientID == %@ AND recordingDate >= %@ AND recordingDate < %@",
                patient.patientID,
                startOfDay as NSDate,
                endOfDay as NSDate
            )
            let query = CKQuery(recordType: "HealthDataRecord", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "recordingDate", ascending: false)]

            let (matchResults, _) = try await publicDatabase.records(matching: query, resultsLimit: 1)

            guard let (_, result) = matchResults.first,
                  case .success(let record) = result else {
                await MainActor.run { self.isLoading = false }
                return nil
            }

            // Extract and decompress sensor data
            guard let compressedData = record["sensorDataCompressed"] as? Data,
                  let uncompressedSize = record["sensorDataUncompressedSize"] as? Int else {
                await MainActor.run { self.isLoading = false }
                return nil
            }

            guard let decompressedData = compressedData.decompressed(expectedSize: uncompressedSize) else {
                Logger.shared.error("[DentistDataManager] Failed to decompress sensor data")
                await MainActor.run { self.isLoading = false }
                return nil
            }

            let sessionData = try JSONDecoder().decode(BruxismSessionData.self, from: decompressedData)

            await MainActor.run { self.isLoading = false }
            return sessionData

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load sensor data: \(error.localizedDescription)"
            }
            throw error
        }
    }

    /// Fetch all sensor data for a patient within a date range (for historical charts)
    func fetchAllPatientSensorData(for patient: DentistPatient, from startDate: Date, to endDate: Date) async throws -> [SerializableSensorData] {
        isLoading = true
        errorMessage = nil

        var allSensorData: [SerializableSensorData] = []

        do {
            let predicate = NSPredicate(
                format: "patientID == %@ AND recordingDate >= %@ AND recordingDate <= %@",
                patient.patientID,
                startDate as NSDate,
                endDate as NSDate
            )
            let query = CKQuery(recordType: "HealthDataRecord", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "recordingDate", ascending: true)]

            let (matchResults, _) = try await publicDatabase.records(matching: query)

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    // Extract and decompress sensor data
                    if let compressedData = record["sensorDataCompressed"] as? Data,
                       let uncompressedSize = record["sensorDataUncompressedSize"] as? Int,
                       let decompressedData = compressedData.decompressed(expectedSize: uncompressedSize) {

                        if let sessionData = try? JSONDecoder().decode(BruxismSessionData.self, from: decompressedData) {
                            allSensorData.append(contentsOf: sessionData.sensorReadings)
                        }
                    }
                case .failure(let error):
                    Logger.shared.error("[DentistDataManager] Error loading record: \(error)")
                }
            }

            await MainActor.run { self.isLoading = false }

            // Sort by timestamp
            return allSensorData.sorted { $0.timestamp < $1.timestamp }

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load sensor data: \(error.localizedDescription)"
            }
            throw error
        }
    }

    // MARK: - Helper Methods

    private func getCurrentDentistID() -> String? {
        // This would get the dentist's Apple ID from Sign in with Apple
        // For now, return a placeholder - will be implemented with actual auth
        return UserDefaults.standard.string(forKey: "dentistAppleID")
    }

    private func getCurrentDentistName() -> String? {
        // Get dentist's name from authentication
        return UserDefaults.standard.string(forKey: "dentistName")
    }
}

// MARK: - Errors

enum DentistDataError: LocalizedError {
    case notAuthenticated
    case invalidShareCode
    case shareCodeNotFound
    case shareCodeExpired
    case patientAlreadyAdded
    case patientLimitReached

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to add patients"
        case .invalidShareCode:
            return "Invalid share code format. Please enter a 6-digit code."
        case .shareCodeNotFound:
            return "Share code not found or has been deactivated"
        case .shareCodeExpired:
            return "This share code has expired. Please request a new code from the patient."
        case .patientAlreadyAdded:
            return "You already have access to this patient's data"
        case .patientLimitReached:
            return "You've reached your patient limit. Please upgrade to add more patients."
        }
    }
}
