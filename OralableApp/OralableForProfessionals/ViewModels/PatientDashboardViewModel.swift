//
//  PatientDashboardViewModel.swift
//  OralableForProfessionals
//
//  ViewModel for patient dashboard - mirrors OralableApp DashboardViewModel
//

import Foundation
import Combine

@MainActor
class PatientDashboardViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var muscleActivity: Double = 0
    @Published var muscleActivityHistory: [Double] = []
    @Published var movementIntensity: Double = 0
    @Published var isMoving: Bool = false
    @Published var accelerometerHistory: [Double] = []
    @Published var heartRate: Int = 0
    @Published var heartRateHistory: [Double] = []
    @Published var temperature: Double = 0

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    // MARK: - Private Properties

    private let patient: ProfessionalPatient
    private let dataManager: ProfessionalDataManager
    private var sensorData: [SerializableSensorData] = []

    // MARK: - Initialization

    init(patient: ProfessionalPatient, dataManager: ProfessionalDataManager = .shared) {
        self.patient = patient
        self.dataManager = dataManager
    }

    // MARK: - Data Loading

    func loadLatestData() async {
        isLoading = true
        errorMessage = nil

        // Load last 24 hours of data
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate) ?? endDate

        do {
            sensorData = try await dataManager.fetchAllPatientSensorData(
                for: patient,
                from: startDate,
                to: endDate
            )

            updateMetrics()
            lastUpdated = Date()

        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Metric Calculations

    private func updateMetrics() {
        guard !sensorData.isEmpty else { return }

        // Get most recent readings (last 100 for sparklines)
        let recentData = Array(sensorData.suffix(100))

        // Muscle Activity (PPG IR as proxy)
        if let latest = recentData.last {
            muscleActivity = Double(latest.ppgIR)
        }
        muscleActivityHistory = recentData.map { Double($0.ppgIR) / 1000.0 } // Normalize for sparkline

        // Movement
        if let latest = recentData.last {
            movementIntensity = latest.accelMagnitude
            isMoving = latest.accelMagnitude > 1.5 // Threshold for "moving"
        }
        accelerometerHistory = recentData.map { $0.accelMagnitude }

        // Heart Rate (most recent valid reading)
        let validHeartRates = recentData.compactMap { $0.heartRateBPM }
        if let latestHR = validHeartRates.last {
            heartRate = Int(latestHR)
        }
        heartRateHistory = validHeartRates

        // Temperature
        if let latest = recentData.last {
            temperature = latest.temperatureCelsius
        }
    }

    // MARK: - Public Accessors

    var patientName: String {
        patient.displayName
    }

    var hasSensorData: Bool {
        !sensorData.isEmpty
    }

    var sensorDataCount: Int {
        sensorData.count
    }
}
