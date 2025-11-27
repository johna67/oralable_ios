import Foundation

@MainActor
extension HistoricalViewModel {
    /// Recommend a sensible time range to show based on available metrics.
    /// This is a lightweight heuristic that prefers the largest range that has data.
    /// Returns nil when there is no useful metric available.
    func getRecommendedTimeRange() -> TimeRange? {
        // Prefer month > week > day > hour if that range has any data points.
        if let m = monthMetrics, !m.dataPoints.isEmpty {
            return .month
        }
        if let w = weekMetrics, !w.dataPoints.isEmpty {
            return .week
        }
        if let d = dayMetrics, !d.dataPoints.isEmpty {
            return .day
        }
        if let h = hourMetrics, !h.dataPoints.isEmpty {
            return .hour
        }

        // Fallback: if currentMetrics exists use selectedTimeRange
        if currentMetrics != nil {
            return selectedTimeRange
        }

        return nil
    }
}