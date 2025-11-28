//
//  PatientHistoricalView.swift
//  OralableForDentists
//
//  Historical view for patient data - mirrors OralableApp HistoricalView
//

import SwiftUI
import Charts

struct PatientHistoricalView: View {
    let patient: DentistPatient
    let metricType: String

    @StateObject private var viewModel: PatientHistoricalViewModel
    @EnvironmentObject var designSystem: DesignSystem

    init(patient: DentistPatient, metricType: String = "Movement") {
        self.patient = patient
        self.metricType = metricType
        _viewModel = StateObject(wrappedValue: PatientHistoricalViewModel(patient: patient))
    }

    // MARK: - Date Format

    private var xAxisDateFormat: Date.FormatStyle {
        switch viewModel.selectedTimeRange {
        case .minute:
            return .dateTime.hour().minute().second()
        case .hour:
            return .dateTime.hour().minute()
        case .day:
            return .dateTime.hour()
        case .week:
            return .dateTime.month().day()
        case .month:
            return .dateTime.month().day()
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !viewModel.dataPoints.isEmpty {
                    Text("Data points: \(viewModel.dataPoints.count)")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                timeRangeSelector

                if viewModel.isLoading {
                    ProgressView("Loading data...")
                        .padding()
                } else if viewModel.hasCurrentMetrics && viewModel.hasSufficientDataForCurrentRange {
                    metricChart
                } else {
                    emptyStateView
                }
            }
            .padding(16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(metricType)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            Task { await viewModel.loadData() }
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        VStack(spacing: 8) {
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                Text("Min").tag(TimeRange.minute)
                Text("Hour").tag(TimeRange.hour)
                Text("Day").tag(TimeRange.day)
                Text("Week").tag(TimeRange.week)
            }
            .pickerStyle(SegmentedPickerStyle())

            HStack {
                Button(action: { viewModel.selectPreviousTimeRange() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                }

                Spacer()

                Text(viewModel.timeRangeText)
                    .font(.headline)

                Spacer()

                Button(action: { viewModel.selectNextTimeRange() }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                }
                .disabled(viewModel.isCurrentTimeRange)
            }
        }
    }

    // MARK: - Chart

    private var metricChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartForMetric
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var chartForMetric: some View {
        switch metricType {
        case "Muscle Activity": muscleActivityChart
        case "Movement": movementChart
        case "Heart Rate": heartRateChart
        case "SpO2": spo2Chart
        default: movementChart
        }
    }

    private var muscleActivityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Muscle Activity")
                .font(.headline)

            Chart(viewModel.dataPoints) { point in
                if let ppgIR = point.averagePPGIR {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Activity", ppgIR)
                    )
                    .foregroundStyle(.purple)
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisDateFormat)
                }
            }
        }
    }

    private var movementChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movement Intensity")
                .font(.headline)

            Chart(viewModel.dataPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Movement", point.movementIntensity)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisDateFormat)
                }
            }
        }
    }

    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate (BPM)")
                .font(.headline)

            Chart(viewModel.dataPoints) { point in
                if let hr = point.averageHeartRate {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Heart Rate", hr)
                    )
                    .foregroundStyle(.red)
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisDateFormat)
                }
            }
        }
    }

    private var spo2Chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blood Oxygen (%)")
                .font(.headline)

            Chart(viewModel.dataPoints) { point in
                if let spo2 = point.averageSpO2 {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("SpO2", spo2)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 250)
            .chartYScale(domain: 85...100)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisDateFormat)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: viewModel.dataPoints.isEmpty
                  ? "chart.line.uptrend.xyaxis.circle"
                  : "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(viewModel.dataPoints.isEmpty ? "No Data in This Range" : "Data Span Too Short")
                .font(.title2.bold())

            Text(viewModel.dataSufficiencyMessage ?? "")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(32)
    }
}
