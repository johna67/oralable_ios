//
//  PatientHistoricalViewModel.swift
//  OralableForDentists
//
//  ViewModel for patient historical charts - mirrors OralableApp HistoricalViewModel
//

import Foundation
import Combine

@MainActor
class PatientHistoricalViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedTimeRange: TimeRange = .hour
    @Published var dataPoints: [HistoricalDataPoint] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var selectedDate: Date = Date()

    // MARK: - Private Properties

    private let patient: DentistPatient
    private let dataManager: DentistDataManager
    private var allSensorData: [SerializableSensorData] = []

    // MARK: - Initialization

    init(patient: DentistPatient, dataManager: DentistDataManager = .shared) {
        self.patient = patient
        self.dataManager = dataManager
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil

        // Load data for the selected time range
        let endDate = selectedDate
        let startDate: Date

        switch selectedTimeRange {
        case .minute:
            startDate = Calendar.current.date(byAdding: .minute, value: -1, to: endDate) ?? endDate
        case .hour:
            startDate = Calendar.current.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
        case .day:
            startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        }

        do {
            allSensorData = try await dataManager.fetchAllPatientSensorData(
                for: patient,
                from: startDate,
                to: endDate
            )

            aggregateData()

        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func aggregateData() {
        let endDate = selectedDate
        let startDate: Date

        switch selectedTimeRange {
        case .minute:
            startDate = Calendar.current.date(byAdding: .minute, value: -1, to: endDate) ?? endDate
        case .hour:
            startDate = Calendar.current.date(byAdding: .hour, value: -1, to: endDate) ?? endDate
        case .day:
            startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        }

        dataPoints = allSensorData.aggregateIntoBuckets(
            bucketDuration: selectedTimeRange.bucketDuration,
            from: startDate,
            to: endDate
        )
    }

    // MARK: - Time Navigation

    func selectPreviousTimeRange() {
        switch selectedTimeRange {
        case .minute:
            selectedDate = Calendar.current.date(byAdding: .minute, value: -1, to: selectedDate) ?? selectedDate
        case .hour:
            selectedDate = Calendar.current.date(byAdding: .hour, value: -1, to: selectedDate) ?? selectedDate
        case .day:
            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        }

        Task { await loadData() }
    }

    func selectNextTimeRange() {
        let newDate: Date

        switch selectedTimeRange {
        case .minute:
            newDate = Calendar.current.date(byAdding: .minute, value: 1, to: selectedDate) ?? selectedDate
        case .hour:
            newDate = Calendar.current.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate
        case .day:
            newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            newDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
        case .month:
            newDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        }

        // Don't go past current time
        if newDate <= Date() {
            selectedDate = newDate
            Task { await loadData() }
        }
    }

    // MARK: - Computed Properties

    var timeRangeText: String {
        let formatter = DateFormatter()

        switch selectedTimeRange {
        case .minute:
            formatter.dateFormat = "HH:mm:ss"
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "MMM d, HH:mm"
        case .week, .month:
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: selectedDate)
    }

    var isCurrentTimeRange: Bool {
        let now = Date()
        switch selectedTimeRange {
        case .minute:
            return Calendar.current.isDate(selectedDate, equalTo: now, toGranularity: .minute)
        case .hour:
            return Calendar.current.isDate(selectedDate, equalTo: now, toGranularity: .hour)
        case .day:
            return Calendar.current.isDate(selectedDate, inSameDayAs: now)
        case .week:
            return Calendar.current.isDate(selectedDate, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return Calendar.current.isDate(selectedDate, equalTo: now, toGranularity: .month)
        }
    }

    var hasCurrentMetrics: Bool {
        !dataPoints.isEmpty
    }

    var hasSufficientDataForCurrentRange: Bool {
        dataPoints.count >= selectedTimeRange.minimumDataPoints
    }

    var dataSufficiencyMessage: String? {
        if dataPoints.isEmpty {
            return "No sensor data available for this time range. The patient may not have recorded any sessions."
        } else if !hasSufficientDataForCurrentRange {
            return "Only \(dataPoints.count) data points available. Need at least \(selectedTimeRange.minimumDataPoints) for meaningful charts."
        }
        return nil
    }
}
