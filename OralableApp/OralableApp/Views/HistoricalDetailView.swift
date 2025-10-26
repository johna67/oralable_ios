import SwiftUI
import Charts

struct HistoricalDetailView: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeRange: TimeRange = .day
    @State private var selectedDate = Date() // For day view navigation
    @State private var selectedDataPoint: SensorData? // For tooltip
    
    // Data availability info
    private var dataAvailability: String {
        if ble.historicalData.isEmpty {
            return "No historical data collected yet"
        }
        
        guard let oldestData = ble.historicalData.first?.timestamp,
              let newestData = ble.historicalData.last?.timestamp else {
            return "No data available"
        }
        
        let duration = newestData.timeIntervalSince(oldestData)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "Data spans: \(hours)h \(minutes)m"
        } else {
            return "Data spans: \(minutes)m (need more time for trends)"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Range Selector
                TimeRangePicker(selectedRange: $selectedTimeRange)
                    .padding()
                    .onChange(of: selectedTimeRange) { _, _ in
                        selectedDate = Date() // Reset to today when time range changes
                    }
                
                // Date Navigation for all views
                DateNavigationView(selectedDate: $selectedDate, timeRange: selectedTimeRange)
                    .padding(.horizontal)
                
                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Enhanced Chart with Withings-style features
                        EnhancedHistoricalChartCard(
                            ble: ble,
                            metricType: metricType,
                            timeRange: selectedTimeRange,
                            selectedDate: selectedDate,
                            selectedDataPoint: $selectedDataPoint
                        )
                        
                        // Enhanced Statistics Card
                        EnhancedStatisticsCard(
                            ble: ble,
                            metricType: metricType,
                            timeRange: selectedTimeRange,
                            selectedDate: selectedDate
                        )
                        
                        // PPG Debug Card (only for PPG metric type)
                        if metricType == .ppg {
                            PPGDebugCard(
                                ble: ble,
                                timeRange: selectedTimeRange,
                                selectedDate: selectedDate
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("\(metricType.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Date Navigation View (Enhanced for all time ranges)
struct DateNavigationView: View {
    @Binding var selectedDate: Date
    let timeRange: TimeRange
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        switch timeRange {
        case .hour:
            formatter.dateFormat = "HH:mm, dd MMM" // Fallback, should not be used
        case .day:
            formatter.dateFormat = "EEEE, dd MMMM"
        case .week:
            formatter.dateFormat = "dd MMM yyyy" // Show week start date
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter
    }
    
    private var displayText: String {
        switch timeRange {
        case .hour:
            return "Hour View" // Fallback
        case .day:
            return dateFormatter.string(from: selectedDate)
        case .week:
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
                let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
                let startFormatter = DateFormatter()
                startFormatter.dateFormat = "dd MMM"
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = "dd MMM yyyy"
                return "\(startFormatter.string(from: weekInterval.start)) - \(endFormatter.string(from: endDate))"
            }
            return "This Week"
        case .month:
            return dateFormatter.string(from: selectedDate)
        }
    }
    
    private func navigateBackward() {
        let calendar = Calendar.current
        switch timeRange {
        case .hour:
            selectedDate = calendar.date(byAdding: .hour, value: -1, to: selectedDate) ?? selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func navigateForward() {
        let calendar = Calendar.current
        switch timeRange {
        case .hour:
            selectedDate = calendar.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        }
    }
    
    // Check if we can navigate forward (don't go beyond today)
    private var canNavigateForward: Bool {
        let calendar = Calendar.current
        let today = Date()
        
        switch timeRange {
        case .hour:
            let currentHourStart = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let thisHourStart = calendar.dateInterval(of: .hour, for: today)?.start ?? today
            return currentHourStart < thisHourStart
        case .day:
            return !calendar.isDate(selectedDate, inSameDayAs: today)
        case .week:
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return currentWeekStart < thisWeekStart
        case .month:
            let currentMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let thisMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
            return currentMonth < thisMonth
        }
    }
    
    var body: some View {
        HStack {
            Button(action: navigateBackward) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack {
                Text(displayText)
                    .font(.headline)
                    .fontWeight(.medium)
                
                // Show current period indicator
                if timeRange != .day {
                    Text(periodInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: navigateForward) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(canNavigateForward ? .blue : .gray)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(!canNavigateForward)
        }
        .padding(.vertical, 8)
    }
    
    private var periodInfo: String {
        let calendar = Calendar.current
        switch timeRange {
        case .hour:
            guard let interval = calendar.dateInterval(of: .hour, for: selectedDate) else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let endTime = calendar.date(byAdding: .minute, value: -1, to: interval.end) ?? interval.end
            return "\(formatter.string(from: interval.start)) - \(formatter.string(from: endTime))"
        case .day:
            return ""
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return "" }
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: interval.start)) - \(formatter.string(from: end))"
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: selectedDate) else { return "" }
            let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 0
            return "\(daysInMonth) days"
        }
    }
}

// MARK: - Data Availability Banner
struct DataAvailabilityBanner: View {
    let dataCount: Int
    let availabilityText: String
    let oldestDate: Date?
    let newestDate: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text("Historical Data Collection")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text(availabilityText)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if let oldest = oldestDate, let newest = newestDate {
                HStack(spacing: 4) {
                    Text("From:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(oldest, style: .date)
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text("to")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(newest, style: .date)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Selected Range Info
struct SelectedRangeInfo: View {
    let timeRange: TimeRange
    let filteredDataCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Showing: Last \(timeRange.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if filteredDataCount == 0 {
                    Text("No data available for this time range")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("\(filteredDataCount) data points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Visual indicator of data sufficiency
            DataSufficiencyIndicator(
                timeRange: timeRange,
                dataCount: filteredDataCount
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Sufficiency Indicator
struct DataSufficiencyIndicator: View {
    let timeRange: TimeRange
    let dataCount: Int
    
    private var status: (text: String, color: Color, icon: String) {
        // Estimate minimum samples needed for meaningful historical view
        let minSamples: Int
        switch timeRange {
        case .hour: minSamples = 20 // ~1 per 3 min
        case .day: minSamples = 50 // ~1 per 30min
        case .week: minSamples = 100 // ~2 per day
        case .month: minSamples = 300 // ~10 per day
        }
        
        if dataCount == 0 {
            return ("No Data", .red, "exclamationmark.triangle.fill")
        } else if dataCount < minSamples / 2 {
            return ("Collecting", .orange, "hourglass")
        } else if dataCount < minSamples {
            return ("Partial", .yellow, "chart.line.uptrend.xyaxis")
        } else {
            return ("Complete", .green, "checkmark.circle.fill")
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.text)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Time Range Picker
struct TimeRangePicker: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        HStack(spacing: 30) {
            ForEach([TimeRange.day, TimeRange.week, TimeRange.month], id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.displayName)
                        .font(.system(size: 17, weight: selectedRange == range ? .semibold : .regular))
                        .foregroundColor(selectedRange == range ? .blue : .primary)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - TimeRange Extension
extension TimeRange {
    var displayName: String {
        switch self {
        case .hour: return "Hour"
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

// MARK: - Enhanced Historical Chart Card (Withings-style)
struct EnhancedHistoricalChartCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    let selectedDate: Date
    @Binding var selectedDataPoint: SensorData?
    
    private var filteredData: [SensorData] {
        let calendar = Calendar.current
        
        switch timeRange {
        case .hour:
            // This case should not be reached since we removed hour from picker
            return []
        case .day:
            // For day view, filter by the selected date
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return ble.historicalData.filter { 
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }.sorted { $0.timestamp < $1.timestamp }
        case .week:
            // For week view, show the week containing the selected date
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek
            }.sorted { $0.timestamp < $1.timestamp }
        case .month:
            // For month view, show the month containing the selected date
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth
            }.sorted { $0.timestamp < $1.timestamp }
        }
    }
    
    // Normalize PPG IR data for Withings-style display
    private var normalizedPPGData: [(timestamp: Date, value: Double)] {
        let ppgValues = filteredData.map { Double($0.ppg.ir) }
        guard !ppgValues.isEmpty else { return [] }
        
        // Apply min-max normalization to scale to 40-200 range (typical HR range)
        let minValue = ppgValues.min() ?? 0
        let maxValue = ppgValues.max() ?? 1
        
        let normalizedData = filteredData.enumerated().map { index, data in
            let normalizedValue: Double
            if maxValue > minValue {
                // Scale to 40-200 range to simulate heart rate values
                let normalized = (Double(data.ppg.ir) - minValue) / (maxValue - minValue)
                normalizedValue = 40 + (normalized * 160) // 40-200 range
            } else {
                normalizedValue = 120 // Default middle value
            }
            return (timestamp: data.timestamp, value: normalizedValue)
        }
        
        return normalizedData
    }
    
    private func getValue(from data: SensorData) -> Double {
        switch metricType {
        case .ppg: return Double(data.ppg.ir) // Use IR as primary PPG value
        case .temperature: return data.temperature
        case .battery: return Double(data.batteryLevel)
        case .accelerometer: return data.accelerometer.magnitude
        }
    }
    
    private var emptyStateMessage: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        switch timeRange {
        case .hour:
            return "Hour view not available" // Fallback
        case .day:
            formatter.dateStyle = .medium
            return "No measurements recorded on \(formatter.string(from: selectedDate))"
        case .week:
            formatter.dateFormat = "dd MMM"
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
                let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
                return "No measurements recorded from \(formatter.string(from: weekInterval.start)) - \(formatter.string(from: endDate))"
            }
            return "No measurements recorded for this week"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return "No measurements recorded in \(formatter.string(from: selectedDate))"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and sample count
            HStack {
                Text(metricType.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            if filteredData.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(emptyStateMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
            } else {
                // Create the chart based on metric type
                Group {
                    if metricType == .ppg {
                        // PPG-specific Withings-style chart
                        Chart {
                            ForEach(Array(normalizedPPGData.enumerated()), id: \.offset) { index, point in
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("PPG IR", point.value)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.catmullRom)
                                
                                // Add subtle area fill like Withings
                                AreaMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("PPG IR", point.value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                            
                            // Selection indicator
                            if let selected = selectedDataPoint {
                                let selectedValue = getValue(from: selected)
                                
                                PointMark(
                                    x: .value("Time", selected.timestamp),
                                    y: .value("PPG IR", selectedValue)
                                )
                                .foregroundStyle(.blue)
                                .symbol(.circle)
                                .symbolSize(80)
                                
                                // Vertical rule mark for time indication
                                RuleMark(
                                    x: .value("Time", selected.timestamp)
                                )
                                .foregroundStyle(.gray.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1))
                            }
                        }
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                updateSelection(at: value.location, geometry: geometry, chartProxy: chartProxy)
                                            }
                                    )
                            }
                        }
                    } else {
                        // Original chart for non-PPG metrics
                        Chart {
                            ForEach(Array(filteredData.enumerated()), id: \.offset) { index, data in
                                LineMark(
                                    x: .value("Time", data.timestamp),
                                    y: .value(metricType.title, getValue(from: data))
                                )
                                .foregroundStyle(metricType.color)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                
                                AreaMark(
                                    x: .value("Time", data.timestamp),
                                    y: .value(metricType.title, getValue(from: data))
                                )
                                .foregroundStyle(metricType.color.opacity(0.1))
                            }
                            
                            // Selection indicator
                            if let selected = selectedDataPoint {
                                PointMark(
                                    x: .value("Time", selected.timestamp),
                                    y: .value(metricType.title, getValue(from: selected))
                                )
                                .foregroundStyle(metricType.color)
                                .symbol(.circle)
                                .symbolSize(100)
                                
                                RuleMark(
                                    x: .value("Time", selected.timestamp)
                                )
                                .foregroundStyle(.gray)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            }
                        }
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                updateSelection(at: value.location, geometry: geometry, chartProxy: chartProxy)
                                            }
                                    )
                            }
                        }
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    switch timeRange {
                    case .hour:
                        // Should not be reached
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.minute())
                        }
                    case .day:
                        AxisMarks(values: .automatic(desiredCount: 7)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    case .week:
                        AxisMarks(values: .automatic(desiredCount: 7)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    case .month:
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.0f", doubleValue))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Tooltip overlay
                if let selected = selectedDataPoint {
                    TooltipOverlay(
                        dataPoint: selected,
                        metricType: metricType,
                        value: getValue(from: selected)
                    )
                }
            }
            
            // Info message like Withings
            Text("Context is key to getting a better understanding of your \(metricType.title).")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
    
    private func updateSelection(at location: CGPoint, geometry: GeometryProxy, chartProxy: ChartProxy) {
        guard !normalizedPPGData.isEmpty else { return }
        
        let plotAreaBounds = chartProxy.plotAreaFrame
        let plotAreaRect = geometry[plotAreaBounds]
        
        let relativeXPosition = location.x - plotAreaRect.origin.x
        let plotWidth = plotAreaRect.width
        let relativePosition = relativeXPosition / plotWidth
        
        guard relativePosition >= 0 && relativePosition <= 1 else { return }
        
        let timeRange = normalizedPPGData.last!.timestamp.timeIntervalSince(normalizedPPGData.first!.timestamp)
        let selectedTimeOffset = relativePosition * timeRange
        let selectedTime = normalizedPPGData.first!.timestamp.addingTimeInterval(selectedTimeOffset)
        
        // Find the closest data point
        let closest = filteredData.min { data1, data2 in
            abs(data1.timestamp.timeIntervalSince(selectedTime)) < 
            abs(data2.timestamp.timeIntervalSince(selectedTime))
        }
        
        selectedDataPoint = closest
    }
}

// MARK: - Tooltip Overlay
struct TooltipOverlay: View {
    let dataPoint: SensorData
    let metricType: MetricType
    let value: Double
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var valueText: String {
        switch metricType {
        case .ppg:
            // For PPG, show the normalized value as if it were a heart rate
            return String(format: "%.0f", value)
        case .temperature:
            return String(format: "%.1f°C", value)
        case .battery:
            return String(format: "%.0f%%", value)
        case .accelerometer:
            return String(format: "%.2f", value)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(timeFormatter.string(from: dataPoint.timestamp))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: metricType.icon)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            Text(valueText)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(metricType.color)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            // Small arrow pointing down
            Path { path in
                let arrowWidth: CGFloat = 8
                let arrowHeight: CGFloat = 4
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: arrowWidth/2, y: arrowHeight))
                path.addLine(to: CGPoint(x: arrowWidth, y: 0))
                path.closeSubpath()
            }
            .fill(metricType.color)
            .offset(y: 6)
            .frame(width: 8, height: 4),
            alignment: .bottom
        )
    }
}

// MARK: - Enhanced Statistics Card
struct EnhancedStatisticsCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    let selectedDate: Date
    
    private var filteredData: [SensorData] {
        let calendar = Calendar.current
        
        switch timeRange {
        case .hour:
            // For hour view, show the hour containing the selected date/time
            let startOfHour = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfHour && $0.timestamp < endOfHour
            }
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return ble.historicalData.filter { 
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
        case .week:
            // For week view, show the week containing the selected date
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek
            }
        case .month:
            // For month view, show the month containing the selected date
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth
            }
        }
    }
    
    private func getValue(from data: SensorData) -> Double {
        switch metricType {
        case .ppg: return Double(data.ppg.ir) // Use IR as primary PPG value
        case .temperature: return data.temperature
        case .battery: return Double(data.batteryLevel)
        case .accelerometer: return data.accelerometer.magnitude
        }
    }
    
    private var statistics: (average: Double, minimum: Double, maximum: Double) {
        let values = filteredData.map(getValue)
        guard !values.isEmpty else { return (0, 0, 0) }
        
        let avg = values.reduce(0, +) / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        
        return (avg, min, max)
    }
    
    private func formatValue(_ value: Double) -> String {
        switch metricType {
        case .ppg:
            return String(format: "%.0f", value)
        case .temperature:
            return String(format: "%.1f°C", value)
        case .battery:
            return String(format: "%.0f%%", value)
        case .accelerometer:
            return String(format: "%.2f", value)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !filteredData.isEmpty {
                let stats = statistics
                
                // Average (main stat like Withings)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatValue(stats.average))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(metricType.color)
                }
                
                Divider()
                
                // Min/Max stats
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(stats.minimum))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(stats.maximum))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
            } else {
                Text("No statistics available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Historical Chart Card
struct HistoricalChartCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    
    private var filteredData: [SensorData] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.seconds)
        return ble.historicalData.filter { $0.timestamp >= cutoffDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metricType.icon)
                    .foregroundColor(metricType.color)
                Text("Historical Trend")
                    .font(.headline)
                Spacer()
                Text("\(filteredData.count) samples")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if filteredData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No data for this time range")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Keep device connected to collect historical data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            } else if filteredData.count < 10 {
                VStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Collecting data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Need more samples for meaningful trends (have \(filteredData.count), need ~20)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            } else {
                if #available(iOS 16.0, *) {
                    switch metricType {
                    case .battery:
                        BatteryHistoricalChart(data: filteredData)
                    case .ppg:
                        PPGHistoricalChart(data: filteredData)
                    case .temperature:
                        TemperatureHistoricalChart(data: filteredData)
                    case .accelerometer:
                        AccelerometerHistoricalChart(data: filteredData)
                    }
                } else {
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 250)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Battery Historical Chart
@available(iOS 16.0, *)
struct BatteryHistoricalChart: View {
    let data: [SensorData]
    
    var body: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Voltage", Int(data[index].batteryVoltage))
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 250)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue) mV")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
}

// MARK: - PPG Historical Chart
@available(iOS 16.0, *)
struct PPGHistoricalChart: View {
    let data: [SensorData]
    @State private var showNormalized: Bool = false
    @State private var normalizationMethod: PPGNormalization = .minMax
    
    enum PPGNormalization: String, CaseIterable {
        case raw = "Raw"
        case minMax = "Min-Max"
        case zScore = "Z-Score"
        case percentage = "Percentage"
    }
    
    private var normalizedData: [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let rawData = data.map { sample in
            (timestamp: sample.timestamp, ir: Double(sample.ppg.ir), red: Double(sample.ppg.red), green: Double(sample.ppg.green))
        }
        
        guard showNormalized else {
            return rawData
        }
        
        return normalizeData(rawData, method: normalizationMethod)
    }
    
    private func normalizeData(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)], method: PPGNormalization) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !data.isEmpty else { return data }
        
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }
        
        switch method {
        case .raw:
            return data
            
        case .minMax:
            let irMin = irValues.min() ?? 0
            let irMax = irValues.max() ?? 1
            let redMin = redValues.min() ?? 0
            let redMax = redValues.max() ?? 1
            let greenMin = greenValues.min() ?? 0
            let greenMax = greenValues.max() ?? 1
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0,
                    red: redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0,
                    green: greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0
                )
            }
            
        case .zScore:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            let irStd = sqrt(irValues.map { pow($0 - irMean, 2) }.reduce(0, +) / Double(irValues.count))
            let redStd = sqrt(redValues.map { pow($0 - redMean, 2) }.reduce(0, +) / Double(redValues.count))
            let greenStd = sqrt(greenValues.map { pow($0 - greenMean, 2) }.reduce(0, +) / Double(greenValues.count))
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irStd > 0 ? (sample.ir - irMean) / irStd : 0,
                    red: redStd > 0 ? (sample.red - redMean) / redStd : 0,
                    green: greenStd > 0 ? (sample.green - greenMean) / greenStd : 0
                )
            }
            
        case .percentage:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMean > 0 ? ((sample.ir - irMean) / irMean) * 100 : 0,
                    red: redMean > 0 ? ((sample.red - redMean) / redMean) * 100 : 0,
                    green: greenMean > 0 ? ((sample.green - greenMean) / greenMean) * 100 : 0
                )
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Controls
            HStack {
                Toggle("Normalize", isOn: $showNormalized)
                    .font(.caption)
                
                if showNormalized {
                    Spacer()
                    
                    Picker("Method", selection: $normalizationMethod) {
                        ForEach(PPGNormalization.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.caption)
                }
            }
            
            Chart {
                ForEach(normalizedData.indices, id: \.self) { index in
                    LineMark(
                        x: .value("Time", normalizedData[index].timestamp),
                        y: .value("IR", normalizedData[index].ir)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    LineMark(
                        x: .value("Time", normalizedData[index].timestamp),
                        y: .value("Red", normalizedData[index].red)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    LineMark(
                        x: .value("Time", normalizedData[index].timestamp),
                        y: .value("Green", normalizedData[index].green)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatYAxisLabel(doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("IR").font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle().fill(.pink).frame(width: 8, height: 8)
                    Text("Red").font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Green").font(.caption2)
                }
                Spacer()
            }
        }
    }
    
    private func formatYAxisLabel(_ value: Double) -> String {
        if showNormalized {
            switch normalizationMethod {
            case .raw:
                return String(format: "%.0f", value)
            case .minMax:
                return String(format: "%.2f", value)
            case .zScore:
                return String(format: "%.1f", value)
            case .percentage:
                return String(format: "%.0f%%", value)
            }
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Temperature Historical Chart
@available(iOS 16.0, *)
struct TemperatureHistoricalChart: View {
    let data: [SensorData]
    
    var body: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Temperature", data[index].temperature)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Temperature", data[index].temperature)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 250)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f°C", doubleValue))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
}

// MARK: - Accelerometer Historical Chart
@available(iOS 16.0, *)
struct AccelerometerHistoricalChart: View {
    let data: [SensorData]
    
    var body: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("X", data[index].accelerometer.x)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Y", data[index].accelerometer.y)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Z", data[index].accelerometer.z)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Magnitude", data[index].accelerometer.magnitude)
                )
                .foregroundStyle(.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .frame(height: 250)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
}

// MARK: - Statistics Card
struct StatisticsCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    
    private var filteredData: [SensorData] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.seconds)
        return ble.historicalData.filter { $0.timestamp >= cutoffDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
            
            if filteredData.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                switch metricType {
                case .battery:
                    BatteryStats(data: filteredData)
                case .ppg:
                    PPGStats(data: filteredData)
                case .temperature:
                    TemperatureStats(data: filteredData)
                case .accelerometer:
                    AccelerometerStats(data: filteredData)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Battery Stats
struct BatteryStats: View {
    let data: [SensorData]
    
    private var avgVoltage: Int {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0) { $0 + Int($1.batteryVoltage) }
        return sum / data.count
    }
    
    private var minVoltage: Int {
        data.map { Int($0.batteryVoltage) }.min() ?? 0
    }
    
    private var maxVoltage: Int {
        data.map { Int($0.batteryVoltage) }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "Average", value: "\(avgVoltage) mV")
            StatRow(label: "Minimum", value: "\(minVoltage) mV")
            StatRow(label: "Maximum", value: "\(maxVoltage) mV")
        }
    }
}

// MARK: - PPG Stats
struct PPGStats: View {
    let data: [SensorData]
    
    private func average(for channel: KeyPath<PPGData, UInt32>) -> Int {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0) { $0 + Int($1.ppg[keyPath: channel]) }
        return sum / data.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "IR Average", value: "\(average(for: \.ir))")
            StatRow(label: "Red Average", value: "\(average(for: \.red))")
            StatRow(label: "Green Average", value: "\(average(for: \.green))")
        }
    }
}

// MARK: - Temperature Stats
struct TemperatureStats: View {
    let data: [SensorData]
    
    private var avgTemp: Double {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0.0) { $0 + $1.temperature }
        return sum / Double(data.count)
    }
    
    private var minTemp: Double {
        data.map { $0.temperature }.min() ?? 0
    }
    
    private var maxTemp: Double {
        data.map { $0.temperature }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "Average", value: String(format: "%.1f°C", avgTemp))
            StatRow(label: "Minimum", value: String(format: "%.1f°C", minTemp))
            StatRow(label: "Maximum", value: String(format: "%.1f°C", maxTemp))
        }
    }
}

// MARK: - Accelerometer Stats
struct AccelerometerStats: View {
    let data: [SensorData]
    
    private var avgMagnitude: Double {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0.0) { $0 + $1.accelerometer.magnitude }
        return sum / Double(data.count)
    }
    
    private var maxMagnitude: Double {
        data.map { $0.accelerometer.magnitude }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "Avg Magnitude", value: String(format: "%.2f", avgMagnitude))
            StatRow(label: "Max Magnitude", value: String(format: "%.2f", maxMagnitude))
        }
    }
}

// MARK: - Helper Views
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - PPG Debug Card
struct PPGDebugCard: View {
    @ObservedObject var ble: OralableBLE
    let timeRange: TimeRange
    let selectedDate: Date
    
    @State private var normalizationMethod: NormalizationMethod = .adaptive
    @State private var detectedSegments: [DataSegment] = []
    @State private var currentSegmentIndex: Int = 0
    
    enum NormalizationMethod: String, CaseIterable {
        case none = "Raw Values"
        case zScore = "Z-Score"
        case minMax = "Min-Max (0-1)"
        case percentage = "Percentage"
        case baseline = "Baseline Corrected"
        case adaptive = "Adaptive (Auto-Recalibrate)"
    }
    
    struct DataSegment: Equatable {
        let id = UUID()
        let startIndex: Int
        let endIndex: Int
        let timestamp: Date
        let isStable: Bool
        let averageVariation: Double
        
        static func == (lhs: DataSegment, rhs: DataSegment) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    private var filteredData: [SensorData] {
        let calendar = Calendar.current
        
        switch timeRange {
        case .hour:
            let startOfHour = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfHour && $0.timestamp < endOfHour
            }.suffix(20) // Show last 20 data points for debugging
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return ble.historicalData.filter { 
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }.suffix(20)
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek
            }.suffix(20)
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth
            }.suffix(20)
        }
    }
    
    private var recentPPGData: [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let rawData = Array(filteredData.map { data in
            (timestamp: data.timestamp, ir: Double(data.ppg.ir), red: Double(data.ppg.red), green: Double(data.ppg.green))
        })
        
        // Update segments when data changes
        DispatchQueue.main.async {
            if normalizationMethod == .adaptive {
                let newSegments = detectDataSegments(rawData)
                if newSegments != detectedSegments {
                    detectedSegments = newSegments
                }
            }
        }
        
        return normalizeData(rawData)
    }
    
    
    private func detectDataSegments(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [DataSegment] {
        guard data.count >= 6 else { return [] }
        
        var segments: [DataSegment] = []
        var currentSegmentStart = 0
        let windowSize = 5 // Samples to analyze for stability
        let movementThreshold: Double = 1000 // Raw value change threshold indicating movement
        let stabilityDuration = 5 // Minimum samples needed to be considered stable
        
        var i = windowSize
        while i < data.count {
            // Calculate variation in the current window
            let windowData = Array(data[(i-windowSize)..<i])
            let variation = calculateWindowVariation(windowData)
            
            // Check if this indicates a significant movement
            let isMovement = variation > movementThreshold
            
            if isMovement || i == data.count - 1 {
                // End current segment
                let segmentEnd = i - windowSize
                if segmentEnd > currentSegmentStart + stabilityDuration {
                    // This segment is long enough to be considered stable
                    let segmentData = Array(data[currentSegmentStart..<segmentEnd])
                    let avgVariation = calculateWindowVariation(segmentData)
                    let isStable = avgVariation < movementThreshold / 2
                    
                    segments.append(DataSegment(
                        startIndex: currentSegmentStart,
                        endIndex: segmentEnd,
                        timestamp: data[currentSegmentStart].timestamp,
                        isStable: isStable,
                        averageVariation: avgVariation
                    ))
                }
                
                // Start new segment after movement settles
                if isMovement {
                    // Skip ahead to allow sensor to settle
                    i += stabilityDuration
                    currentSegmentStart = i
                }
            }
            
            i += 1
        }
        
        // Add final segment if it's long enough
        if currentSegmentStart < data.count - stabilityDuration {
            let segmentData = Array(data[currentSegmentStart..<data.count])
            let avgVariation = calculateWindowVariation(segmentData)
            let isStable = avgVariation < movementThreshold / 2
            
            segments.append(DataSegment(
                startIndex: currentSegmentStart,
                endIndex: data.count,
                timestamp: data[currentSegmentStart].timestamp,
                isStable: isStable,
                averageVariation: avgVariation
            ))
        }
        
        return segments
    }
    
    private func calculateWindowVariation(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> Double {
        guard data.count > 1 else { return 0 }
        
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }
        
        // Calculate standard deviation for each channel
        func standardDeviation(_ values: [Double]) -> Double {
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            return sqrt(variance)
        }
        
        let irStd = standardDeviation(irValues)
        let redStd = standardDeviation(redValues)
        let greenStd = standardDeviation(greenValues)
        
        // Return maximum variation across all channels
        return max(irStd, max(redStd, greenStd))
    }
    
    private func normalizeData(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !data.isEmpty else { return data }
        
        if normalizationMethod == .adaptive {
            return adaptiveNormalization(data)
        }
        
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }

        switch normalizationMethod {
        case .none:
            return data
            
        case .zScore:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            let irStd = sqrt(irValues.map { pow($0 - irMean, 2) }.reduce(0, +) / Double(irValues.count))
            let redStd = sqrt(redValues.map { pow($0 - redMean, 2) }.reduce(0, +) / Double(redValues.count))
            let greenStd = sqrt(greenValues.map { pow($0 - greenMean, 2) }.reduce(0, +) / Double(greenValues.count))
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irStd > 0 ? (sample.ir - irMean) / irStd : 0,
                    red: redStd > 0 ? (sample.red - redMean) / redStd : 0,
                    green: greenStd > 0 ? (sample.green - greenMean) / greenStd : 0
                )
            }
            
        case .minMax:
            let irMin = irValues.min() ?? 0
            let irMax = irValues.max() ?? 1
            let redMin = redValues.min() ?? 0
            let redMax = redValues.max() ?? 1
            let greenMin = greenValues.min() ?? 0
            let greenMax = greenValues.max() ?? 1
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0,
                    red: redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0,
                    green: greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0
                )
            }
            
        case .percentage:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMean > 0 ? ((sample.ir - irMean) / irMean) * 100 : 0,
                    red: redMean > 0 ? ((sample.red - redMean) / redMean) * 100 : 0,
                    green: greenMean > 0 ? ((sample.green - greenMean) / greenMean) * 100 : 0
                )
            }
            
        case .baseline:
            // Use first 3 samples as baseline (if available)
            let baselineCount = min(3, data.count)
            guard baselineCount > 0 else { return data }
            
            let irBaseline = Array(irValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            let redBaseline = Array(redValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            let greenBaseline = Array(greenValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: sample.ir - irBaseline,
                    red: sample.red - redBaseline,
                    green: sample.green - greenBaseline
                )
            }
            
        case .adaptive:
            return adaptiveNormalization(data) // This case is handled above, but included for completeness
        }
    }
    
    private func adaptiveNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !detectedSegments.isEmpty else {
            // If no segments detected yet, use min-max normalization on all data
            return normalizeSegment(data, using: .minMax)
        }
        
        var normalizedData: [(timestamp: Date, ir: Double, red: Double, green: Double)] = []
        
        for segment in detectedSegments {
            let segmentData = Array(data[segment.startIndex..<min(segment.endIndex, data.count)])
            
            if segment.isStable && segmentData.count >= 5 {
                // Use segment-specific normalization for stable segments
                let normalized = normalizeSegment(segmentData, using: .minMax)
                normalizedData.append(contentsOf: normalized)
            } else {
                // For unstable segments, use baseline correction from the segment start
                let normalized = normalizeSegment(segmentData, using: .baseline)
                normalizedData.append(contentsOf: normalized)
            }
        }
        
        return normalizedData
    }
    
    private func normalizeSegment(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)], using method: NormalizationMethod) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !data.isEmpty else { return data }
        
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }
        
        switch method {
        case .minMax:
            let irMin = irValues.min() ?? 0
            let irMax = irValues.max() ?? 1
            let redMin = redValues.min() ?? 0
            let redMax = redValues.max() ?? 1
            let greenMin = greenValues.min() ?? 0
            let greenMax = greenValues.max() ?? 1
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0,
                    red: redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0,
                    green: greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0
                )
            }
            
        case .baseline:
            // Use first sample as baseline for this segment
            let irBaseline = data.first?.ir ?? 0
            let redBaseline = data.first?.red ?? 0
            let greenBaseline = data.first?.green ?? 0
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: sample.ir - irBaseline,
                    red: sample.red - redBaseline,
                    green: sample.green - greenBaseline
                )
            }
            
        default:
            return data
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.red)
                Text("PPG Channel Debug")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Last \(recentPPGData.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Normalization Method Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Normalization Method")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Normalization", selection: $normalizationMethod) {
                    ForEach(NormalizationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                // Normalization explanation
                Text(normalizationExplanation)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                // Show adaptive normalization info
                if normalizationMethod == .adaptive && !detectedSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Detected \(detectedSegments.count) data segments:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        ForEach(Array(detectedSegments.enumerated()), id: \.element.id) { index, segment in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(segment.isStable ? .green : .orange)
                                    .frame(width: 6, height: 6)
                                
                                Text("Segment \(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                
                                Text(segment.isStable ? "Stable" : "Movement")
                                    .font(.caption2)
                                    .foregroundColor(segment.isStable ? .green : .orange)
                                
                                Spacer()
                                
                                Text("\(segment.endIndex - segment.startIndex) samples")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Segment selector for detailed view
                        if detectedSegments.count > 1 {
                            HStack {
                                Text("View segment:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Picker("Segment", selection: $currentSegmentIndex) {
                                    Text("All").tag(-1)
                                    ForEach(0..<detectedSegments.count, id: \.self) { index in
                                        Text("\(index + 1)").tag(index)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.caption2)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.bottom, 8)
            
            if recentPPGData.isEmpty {
                Text("No PPG data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 100)
            } else {
                VStack(spacing: 8) {
                    // Channel switching detection
                    if let detection = detectChannelSwitching() {
                        HStack {
                            Image(systemName: detection.isDetected ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(detection.isDetected ? .orange : .green)
                            Text(detection.message)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Recent values table
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            let displayData = getDisplayData()
                            ForEach(Array(displayData.enumerated().reversed()), id: \.offset) { index, data in
                                VStack(spacing: 4) {
                                    Text(timeFormatter.string(from: data.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(spacing: 2) {
                                        HStack {
                                            Circle()
                                                .fill(.red)
                                                .frame(width: 6, height: 6)
                                            Text(formatNormalizedValue(data.ir))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                        
                                        HStack {
                                            Circle()
                                                .fill(.pink)
                                                .frame(width: 6, height: 6)
                                            Text(formatNormalizedValue(data.red))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                        
                                        HStack {
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 6, height: 6)
                                            Text(formatNormalizedValue(data.green))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    
                                    // Show segment indicator for adaptive mode
                                    if normalizationMethod == .adaptive {
                                        let segmentInfo = getSegmentInfo(for: index, in: displayData.count)
                                        if let info = segmentInfo {
                                            Circle()
                                                .fill(info.isStable ? .green : .orange)
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Channel statistics
                    if let stats = calculateChannelStats() {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("IR Avg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatNormalizedValue(stats.irAvg))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Red Avg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatNormalizedValue(stats.redAvg))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Green Avg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatNormalizedValue(stats.greenAvg))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Variation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%%", stats.variation))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(stats.variation > 30 ? .orange : .primary)
                            }
                            
                            if normalizationMethod == .adaptive && !detectedSegments.isEmpty {
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Stability")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    let stableSegments = detectedSegments.filter { $0.isStable }.count
                                    Text("\(stableSegments)/\(detectedSegments.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(stableSegments == detectedSegments.count ? .green : .orange)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    private func detectChannelSwitching() -> (isDetected: Bool, message: String)? {
        guard recentPPGData.count >= 4 else { return nil }
        
        let recent = Array(recentPPGData.suffix(4))
        
        // Check if any channel values are switching positions
        var switchingDetected = false
        var patterns: [String] = []
        
        let tolerance: Double = normalizationMethod == .none ? 100 : 0.1 // Adjust tolerance based on normalization
        
        for i in 1..<recent.count {
            let prev = recent[i-1]
            let curr = recent[i]
            
            // Check if IR and Red values swapped
            if abs(prev.ir - curr.red) < tolerance && abs(prev.red - curr.ir) < tolerance {
                patterns.append("IR↔Red")
                switchingDetected = true
            }
            
            // Check if IR and Green values swapped
            if abs(prev.ir - curr.green) < tolerance && abs(prev.green - curr.ir) < tolerance {
                patterns.append("IR↔Green")
                switchingDetected = true
            }
            
            // Check if Red and Green values swapped
            if abs(prev.red - curr.green) < tolerance && abs(prev.green - curr.red) < tolerance {
                patterns.append("Red↔Green")
                switchingDetected = true
            }
        }
        
        if switchingDetected {
            let uniquePatterns = Array(Set(patterns))
            return (true, "⚠️ Channel switching detected: \(uniquePatterns.joined(separator: ", "))")
        } else {
            return (false, "✅ Channels appear stable")
        }
    }
    
    private func calculateChannelStats() -> (irAvg: Double, redAvg: Double, greenAvg: Double, variation: Double)? {
        let statsData = getDisplayData()
        guard !statsData.isEmpty else { return nil }
        
        let irValues = statsData.map { $0.ir }
        let redValues = statsData.map { $0.red }
        let greenValues = statsData.map { $0.green }
        
        let irAvg = irValues.reduce(0, +) / Double(irValues.count)
        let redAvg = redValues.reduce(0, +) / Double(redValues.count)
        let greenAvg = greenValues.reduce(0, +) / Double(greenValues.count)
        
        // Calculate coefficient of variation as a percentage
        let allValues = irValues + redValues + greenValues
        let overallAvg = allValues.reduce(0, +) / Double(allValues.count)
        let variance = allValues.map { pow($0 - overallAvg, 2) }.reduce(0, +) / Double(allValues.count)
        let stdDev = sqrt(variance)
        let variation = overallAvg != 0 ? (stdDev / abs(overallAvg)) * 100 : 0
        
        return (irAvg: irAvg, redAvg: redAvg, greenAvg: greenAvg, variation: variation)
    }
    
    private var normalizationExplanation: String {
        switch normalizationMethod {
        case .none:
            return "Raw sensor values (0-65535)"
        case .zScore:
            return "Standardized values (mean=0, std=1)"
        case .minMax:
            return "Scaled to 0-1 range"
        case .percentage:
            return "Percentage change from mean"
        case .baseline:
            return "Relative to first 3 samples"
        case .adaptive:
            return "Auto-detects sensor movement and recalibrates normalization for each stable period"
        }
    }
    
    private func getDisplayData() -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        if normalizationMethod == .adaptive && currentSegmentIndex >= 0 && currentSegmentIndex < detectedSegments.count {
            // Show only selected segment
            let segment = detectedSegments[currentSegmentIndex]
            let segmentData = Array(recentPPGData[segment.startIndex..<min(segment.endIndex, recentPPGData.count)])
            return segmentData
        } else {
            // Show all data (limited to last 20 for display)
            return Array(recentPPGData.suffix(20))
        }
    }
    
    private func getSegmentInfo(for index: Int, in displayCount: Int) -> (isStable: Bool, segmentIndex: Int)? {
        guard normalizationMethod == .adaptive && !detectedSegments.isEmpty else { return nil }
        
        // Map display index back to original data index
        let originalIndex = recentPPGData.count - displayCount + index
        
        // Find which segment this data point belongs to
        for (segmentIndex, segment) in detectedSegments.enumerated() {
            if originalIndex >= segment.startIndex && originalIndex < segment.endIndex {
                return (isStable: segment.isStable, segmentIndex: segmentIndex)
            }
        }
        
        return nil
    }
    
    private func formatNormalizedValue(_ value: Double) -> String {
        switch normalizationMethod {
        case .none:
            return String(format: "%.0f", value)
        case .zScore:
            return String(format: "%.2f", value)
        case .minMax, .adaptive:
            return String(format: "%.3f", value)
        case .percentage:
            return String(format: "%.1f%%", value)
        case .baseline:
            return String(format: "%.0f", value)
        }
    }
}
