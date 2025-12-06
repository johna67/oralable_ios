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
        case "Muscle Activity": muscleActivityChart(isEMG: false)
        case "EMG Activity": muscleActivityChart(isEMG: true)
        case "Movement": accelerometerChart
        case "Heart Rate": heartRateChart
        case "SpO2": spo2Chart
        case "Temperature": temperatureChart
        case "PPG": ppgChart
        default: accelerometerChart
        }
    }

    // MARK: - Chart Implementations
    private var accelerometerChart: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            // Header with current value
            HStack {
                Text("Movement (g)")
                    .font(designSystem.typography.headline)
                    .foregroundColor(designSystem.colors.textPrimary)

                Spacer()

                // Show latest value in g-units
                if let latest = viewModel.dataPoints.last {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(latest.isAtRest ? Color.blue : Color.green)
                            .frame(width: 8, height: 8)
                        Text(String(format: "%.2f g", latest.movementIntensityInG))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
            }

            // Chart with g-unit values
            Chart(viewModel.dataPoints) { point in
                PointMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Acceleration", point.movementIntensityInG)
                )
                .foregroundStyle(point.isAtRest ? Color.blue.opacity(0.6) : Color.green.opacity(0.8))
                .symbolSize(10)
            }
            .frame(height: 250)
            .chartYScale(domain: 0...3)  // 0 to 3g range
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let g = value.as(Double.self) {
                            Text(String(format: "%.1f", g))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisDateFormat)
                }
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("At Rest (~1g)")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 8, height: 8)
                    Text("Moving")
                        .font(.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                }
            }
            .padding(.top, 4)
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

    private var temperatureChart: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Temperature (°C)")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)

            Chart(viewModel.dataPoints) { point in
                // averageTemperature is non-optional, filter out default/invalid values
                if point.averageTemperature > 0 {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Temperature", point.averageTemperature)
                    )
                    .foregroundStyle(.orange)
                }
            }
            .frame(height: 250)
            .chartYScale(domain: 30...42)  // Normal body temperature range
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let temp = value.as(Double.self) {
                            Text(String(format: "%.0f°", temp))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisDateFormat)
                }
            }
        }
    }

    /// Muscle Activity chart - shows EMG data (ANR M40) or IR data (Oralable)
    /// - Parameter isEMG: true for ANR M40 (blue), false for Oralable IR (purple)
    private func muscleActivityChart(isEMG: Bool) -> some View {
        let chartTitle = isEMG ? "EMG Activity (ANR M40)" : "Muscle Activity (IR)"
        let chartColor: Color = isEMG ? .blue : .purple

        return VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text(chartTitle)
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)

            Chart(viewModel.dataPoints) { point in
                if let ppgIR = point.averagePPGIR {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Activity", ppgIR)
                    )
                    .foregroundStyle(chartColor)
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
