//
//  HistoricalView.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


//
//  HistoricalView.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Uses HistoricalViewModel (MVVM pattern)
//

import SwiftUI
import Charts

struct HistoricalView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var historicalDataManager: HistoricalDataManager
    @EnvironmentObject var bleManager: OralableBLE
    @State private var viewModel: HistoricalViewModel?
    @State private var selectedDataPoint: HistoricalDataPoint?
    @State private var showingExportSheet = false
    @State private var showingDatePicker = false

    let metricType: String // "Movement", "HeartRate", "SpO2", etc.

    init(metricType: String = "Movement") {
        self.metricType = metricType
        Logger.shared.info("[HistoricalView] Initialized with metricType: \(metricType)")
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                historicalContent(viewModel: vm)
            } else {
                ProgressView("Loading...")
                    .task {
                        // Initialize viewModel from environment's historicalDataManager
                        if viewModel == nil {
                            Logger.shared.info("[HistoricalView] Creating ViewModel with historicalDataManager from environment")
                            viewModel = HistoricalViewModel(historicalDataManager: historicalDataManager)
                        }
                    }
            }
        }
        .navigationTitle(metricType)
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func historicalContent(viewModel: HistoricalViewModel) -> some View {
        ScrollView {
            VStack(spacing: designSystem.spacing.lg) {
                // Debug info
                if !viewModel.dataPoints.isEmpty {
                    Text("Data points: \(viewModel.dataPoints.count)")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Time Range Selector
                timeRangeSelector(viewModel: viewModel)

                // Chart for selected metric
                if viewModel.hasCurrentMetrics {
                    metricChart(viewModel: viewModel)
                } else {
                    emptyStateView
                }
            }
            .padding(designSystem.spacing.md)
        }
        .onAppear {
            Logger.shared.debug("[HistoricalView] View appeared for metric: \(metricType)")

            // Check BLE sensor data immediately
            let bleDataCount = bleManager.sensorDataHistory.count
            Logger.shared.info("[HistoricalView] ⚠️ BLE sensorDataHistory count: \(bleDataCount)")

            if bleDataCount == 0 {
                Logger.shared.warning("[HistoricalView] ❌ No sensor data in BLE history - cannot show historical data")
            } else {
                Logger.shared.info("[HistoricalView] ✅ Found \(bleDataCount) sensor data entries")

                // Log first and last entry timestamps
                if let first = bleManager.sensorDataHistory.first,
                   let last = bleManager.sensorDataHistory.last {
                    Logger.shared.info("[HistoricalView] Data range: \(first.timestamp) to \(last.timestamp)")
                }
            }

            viewModel.updateAllMetrics()

            // Force another update after a short delay to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Logger.shared.debug("[HistoricalView] Triggering delayed update for metric: \(metricType)")
                Logger.shared.info("[HistoricalView] Current metrics available: \(viewModel.hasCurrentMetrics)")
                Logger.shared.info("[HistoricalView] Data points count: \(viewModel.dataPoints.count)")
                viewModel.updateCurrentRangeMetrics()
            }
        }
    }

    // MARK: - Time Range Selector

    private func timeRangeSelector(viewModel: HistoricalViewModel) -> some View {
        VStack(spacing: designSystem.spacing.sm) {
            Picker("Time Range", selection: Binding(
                get: { viewModel.selectedTimeRange },
                set: { newValue in
                    viewModel.selectedTimeRange = newValue
                    viewModel.updateCurrentRangeMetrics()
                }
            )) {
                Text("Hour").tag(TimeRange.hour)
                Text("Day").tag(TimeRange.day)
                Text("Week").tag(TimeRange.week)
            }
            .pickerStyle(SegmentedPickerStyle())

            // Navigation Arrows
            HStack {
                Button(action: { viewModel.selectPreviousTimeRange() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .background(designSystem.colors.backgroundTertiary)
                        .cornerRadius(designSystem.cornerRadius.small)
                }

                Spacer()

                Text(viewModel.timeRangeText)
                    .font(designSystem.typography.headline)
                    .foregroundColor(designSystem.colors.textPrimary)

                Spacer()

                Button(action: { viewModel.selectNextTimeRange() }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .background(designSystem.colors.backgroundTertiary)
                        .cornerRadius(designSystem.cornerRadius.small)
                }
                .disabled(viewModel.isCurrentTimeRange)
            }
            .foregroundColor(designSystem.colors.textPrimary)
        }
    }

    // MARK: - Metric Chart

    private func metricChart(viewModel: HistoricalViewModel) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            chartForMetric(viewModel: viewModel)
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    @ViewBuilder
    private func chartForMetric(viewModel: HistoricalViewModel) -> some View {
        switch metricType {
        case "Movement":
            accelerometerChart(viewModel: viewModel)
        case "Heart Rate":
            heartRateChart(viewModel: viewModel)
        case "SpO2":
            spo2Chart(viewModel: viewModel)
        default:
            accelerometerChart(viewModel: viewModel)
        }
    }

    private func accelerometerChart(viewModel: HistoricalViewModel) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Movement Activity")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            if !viewModel.dataPoints.isEmpty {
                Chart(viewModel.dataPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Activity", point.movementIntensity)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 300)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                Text("No movement data available")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func heartRateChart(viewModel: HistoricalViewModel) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Heart Rate")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            if !viewModel.dataPoints.isEmpty {
                Chart(viewModel.dataPoints.filter { $0.averageHeartRate != nil }) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("BPM", point.averageHeartRate ?? 0)
                    )
                    .foregroundStyle(.red)
                }
                .frame(height: 300)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                Text("No heart rate data available")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func spo2Chart(viewModel: HistoricalViewModel) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Blood Oxygen")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            if !viewModel.dataPoints.isEmpty {
                Chart(viewModel.dataPoints.filter { $0.averageSpO2 != nil }) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("SpO2", point.averageSpO2 ?? 0)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 300)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                Text("No SpO2 data available")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: designSystem.spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(designSystem.colors.textTertiary)

            Text("No Data Available")
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)

            Text("Connect your device to start collecting \(metricType.lowercased()) data")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(designSystem.spacing.xl)
    }
}
