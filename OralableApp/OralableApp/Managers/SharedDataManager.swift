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
    static let shared = SharedDataManager()

    @Published var sharedDentists: [SharedDentist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let userID: String?

    private init() {
        // Use shared container for both patient and dentist apps
        self.container = CKContainer(identifier: "iCloud.com.jacdental.oralable.shared")
        self.publicDatabase = container.publicCloudDatabase

        // Get patient's user ID (from authentication)
        self.userID = AuthenticationManager.shared.userID

        loadSharedDentists()
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
                    print("Error fetching record: \(error)")
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
                        print("Error loading dentist: \(error)")
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
        // TODO: Implement fetching health data from local storage
        // This will query your existing health data storage and return records
        // Format them for CloudKit sharing
        return []
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
}
