import SwiftUI
import Charts

struct HistoricalView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var historicalDataManager: HistoricalDataManager

    @StateObject private var viewModel: HistoricalViewModel

    let metricType: String

    init(metricType: String = "Movement",
         historicalDataManager: HistoricalDataManager) {
        self.metricType = metricType
        // Create the ViewModel directly here
        _viewModel = StateObject(
            wrappedValue: HistoricalViewModel(
                historicalDataManager: historicalDataManager
            )
        )
        Logger.shared.info("[HistoricalView] Initialized with metricType: \(metricType)")
    }
    
    // MARK: - Computed Properties
    
    /// Date format for x-axis labels based on selected time range
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
            VStack(spacing: designSystem.spacing.lg) {
                if !viewModel.dataPoints.isEmpty {
                    Text("Data points: \(viewModel.dataPoints.count)")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                timeRangeSelector

                if viewModel.hasCurrentMetrics && viewModel.hasSufficientDataForCurrentRange {
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
            Logger.shared.debug("[HistoricalView] View appeared for metric: \(metricType)")
            viewModel.updateAllMetrics()
        }
    }

    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        VStack(spacing: designSystem.spacing.sm) {
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
        case "Movement": accelerometerChart
        case "Heart Rate": heartRateChart
        case "SpO2": spo2Chart
        case "PPG": ppgChart
        default: accelerometerChart
        }
    }

    // MARK: - Chart Implementations
    private var accelerometerChart: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Movement Data")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
            
            Chart(viewModel.dataPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Movement", point.movementIntensity)
                )
                .foregroundStyle(designSystem.colors.info)
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
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Heart Rate (bpm)")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
            
            Chart(viewModel.dataPoints) { point in
                if let heartRate = point.averageHeartRate {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Heart Rate", heartRate)
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
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Blood Oxygen (%)")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
            
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

    private var ppgChart: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("PPG Signal (IR)")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)

            Chart(viewModel.dataPoints) { point in
                if let ppgIR = point.averagePPGIR {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("PPG IR", ppgIR)
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

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: designSystem.spacing.lg) {
            Image(systemName: viewModel.dataPoints.isEmpty
                  ? "chart.line.uptrend.xyaxis.circle"
                  : "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(designSystem.colors.textTertiary)

            Text(viewModel.dataPoints.isEmpty ? "No Data in This Range" : "Data Span Too Short")
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)

            Text(viewModel.dataSufficiencyMessage ?? "")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(designSystem.spacing.xl)
    }
}
