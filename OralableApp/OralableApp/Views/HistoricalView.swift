import SwiftUI
import Charts

struct HistoricalView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var historicalDataManager: HistoricalDataManager
    @EnvironmentObject var bleManager: OralableBLE

    @StateObject private var viewModel: HistoricalViewModel

    let metricType: String

    init(metricType: String = "Movement",
         historicalDataManager: HistoricalDataManager,
         bleManager: OralableBLE) {
        self.metricType = metricType
        // Create the ViewModel directly here
        _viewModel = StateObject(
            wrappedValue: HistoricalViewModel(
                historicalDataManager: historicalDataManager,
                bleManager: bleManager
            )
        )
        Logger.shared.info("[HistoricalView] Initialized with metricType: \(metricType)")
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
        default: accelerometerChart
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: designSystem.spacing.lg) {
            Image(systemName: bleManager.sensorDataHistory.isEmpty
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
