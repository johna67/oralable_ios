import Foundation
import Combine

@MainActor
class PatientListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var patients: [ProfessionalPatient] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var showingAddPatient: Bool = false
    @Published var selectedPatient: ProfessionalPatient?

    // MARK: - Dependencies

    private let dataManager: ProfessionalDataManager
    private let subscriptionManager: ProfessionalSubscriptionManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var filteredPatients: [ProfessionalPatient] {
        if searchText.isEmpty {
            return patients
        }
        return patients.filter { patient in
            patient.displayName.localizedCaseInsensitiveContains(searchText) ||
            patient.patientID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var canAddMorePatients: Bool {
        return subscriptionManager.canAddMorePatients(currentCount: patients.count)
    }

    var patientsRemaining: String {
        let remaining = subscriptionManager.patientsRemaining(currentCount: patients.count)
        if remaining == .max {
            return "Unlimited"
        }
        return "\(remaining) remaining"
    }

    var currentTier: ProfessionalSubscriptionTier {
        return subscriptionManager.currentTier
    }

    // MARK: - Initialization

    init(dataManager: ProfessionalDataManager, subscriptionManager: ProfessionalSubscriptionManager) {
        self.dataManager = dataManager
        self.subscriptionManager = subscriptionManager

        // Subscribe to data manager updates
        dataManager.$patients
            .receive(on: DispatchQueue.main)
            .assign(to: &$patients)

        dataManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        dataManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }

    // MARK: - Actions

    func loadPatients() {
        dataManager.loadPatients()
    }

    func showAddPatient() {
        if canAddMorePatients {
            showingAddPatient = true
        } else {
            errorMessage = "You've reached your patient limit. Please upgrade your subscription."
        }
    }

    func removePatient(_ patient: ProfessionalPatient) {
        Task {
            do {
                try await dataManager.removePatient(patient)
            } catch {
                errorMessage = "Failed to remove patient: \(error.localizedDescription)"
            }
        }
    }

    func selectPatient(_ patient: ProfessionalPatient) {
        selectedPatient = patient
    }

    func clearError() {
        errorMessage = nil
    }

    func refreshPatients() async {
        dataManager.loadPatients()
    }
}
