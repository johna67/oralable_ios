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
    @StateObject private var viewModel: HistoricalViewModel

    let metricType: String // "Movement", "HeartRate", "SpO2", etc.

    init(metricType: String = "Movement") {
        self.metricType = metricType
        let manager = HistoricalDataManager.shared
        _viewModel = StateObject(wrappedValue: HistoricalViewModel(historicalDataManager: manager))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: designSystem.spacing.lg) {
                // Time Range Selector
                timeRangeSelector

                // Chart for selected metric
                if viewModel.hasCurrentMetrics {
                    metricChart
                } else {
                    emptyStateView
                }
            }
            .padding(designSystem.spacing.md)
        }
        .navigationTitle(metricType)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.updateAllMetrics()
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        VStack(spacing: designSystem.spacing.sm) {
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                Text("Day").tag(TimeRange.day)
                Text("Week").tag(TimeRange.week)
                Text("Month").tag(TimeRange.month)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.selectedTimeRange) { _ in
                viewModel.updateCurrentRangeMetrics()
            }

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

    private var metricChart: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            chartForMetric
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    @ViewBuilder
    private var chartForMetric: some View {
        switch metricType {
        case "Movement":
            accelerometerChart
        case "Heart Rate":
            heartRateChart
        case "SpO2":
            spo2Chart
        default:
            accelerometerChart
        }
    }

    private var accelerometerChart: some View {
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

    private var heartRateChart: some View {
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

    private var spo2Chart: some View {
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
