//
//  HistoricalDataProcessor.swift
//  OralableApp
//
//  Background actor for processing historical data without blocking the UI
//

import Foundation

/// Background actor for heavy data processing
actor HistoricalDataProcessor {

    // MARK: - Cached Results

    private var cachedAggregations: [CacheKey: AggregatedMetrics] = [:]
    private let maxCacheSize = 50

    struct CacheKey: Hashable {
        let timeRange: String
        let dataPointsHash: Int

        init(timeRange: String, dataPoints: [HistoricalDataPoint]) {
            self.timeRange = timeRange
            // Create hash from count and first/last timestamps for quick comparison
            var hasher = Hasher()
            hasher.combine(dataPoints.count)
            hasher.combine(dataPoints.first?.timestamp)
            hasher.combine(dataPoints.last?.timestamp)
            self.dataPointsHash = hasher.finalize()
        }
    }

    // MARK: - Aggregated Metrics

    struct AggregatedMetrics {
        // Averages
        let averageHeartRate: Double?
        let averageSpO2: Double?
        let averageTemperature: Double
        let averageBattery: Double

        // Ranges
        let minHeartRate: Double?
        let maxHeartRate: Double?
        let minSpO2: Double?
        let maxSpO2: Double?
        let minTemperature: Double
        let maxTemperature: Double

        // Activity
        let totalActivityIntensity: Double
        let totalGrindingEvents: Int

        // Quality
        let heartRateQualityAverage: Double
        let spo2QualityAverage: Double

        // Metadata
        let dataPointsCount: Int
        let validHeartRateCount: Int
        let validSpO2Count: Int
    }

    // MARK: - Public Methods

    /// Aggregate metrics from data points (runs on background thread)
    func aggregateMetrics(for dataPoints: [HistoricalDataPoint], timeRange: String) async -> AggregatedMetrics {
        let cacheKey = CacheKey(timeRange: timeRange, dataPoints: dataPoints)

        // Check cache first
        if let cached = cachedAggregations[cacheKey] {
            return cached
        }

        // Perform calculation
        let result = await calculateAggregations(dataPoints)

        // Cache the result
        cachedAggregations[cacheKey] = result

        // Manage cache size
        if cachedAggregations.count > maxCacheSize {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = cachedAggregations.keys.prefix(cachedAggregations.count - maxCacheSize)
            for key in keysToRemove {
                cachedAggregations.removeValue(forKey: key)
            }
        }

        return result
    }

    /// Generate chart data points (runs on background thread)
    func generateChartData(for dataPoints: [HistoricalDataPoint], metric: MetricType) async -> [ChartDataPoint] {
        return dataPoints.compactMap { point in
            guard let value = extractMetricValue(from: point, metric: metric) else {
                return nil
            }
            return ChartDataPoint(timestamp: point.timestamp, value: value)
        }
    }

    /// Calculate trend (positive = increasing, negative = decreasing)
    func calculateTrend(for dataPoints: [HistoricalDataPoint], metric: MetricType) async -> Double {
        guard dataPoints.count >= 2 else { return 0 }

        let values = dataPoints.compactMap { extractMetricValue(from: $0, metric: metric) }
        guard values.count >= 2 else { return 0 }

        // Calculate linear trend using first and last third of data
        let thirdSize = max(values.count / 3, 1)
        let firstThird = values.prefix(thirdSize)
        let lastThird = values.suffix(thirdSize)

        let avgFirst = firstThird.reduce(0, +) / Double(firstThird.count)
        let avgLast = lastThird.reduce(0, +) / Double(lastThird.count)

        return avgLast - avgFirst
    }

    /// Clear all caches
    func clearCache() {
        cachedAggregations.removeAll()
    }

    // MARK: - Private Calculation Methods

    private func calculateAggregations(_ dataPoints: [HistoricalDataPoint]) async -> AggregatedMetrics {
        // Extract all values
        let heartRates = dataPoints.compactMap { $0.averageHeartRate }
        let spo2Values = dataPoints.compactMap { $0.averageSpO2 }
        let temperatures = dataPoints.map { $0.averageTemperature }
        let batteries = dataPoints.map { Double($0.averageBattery) }
        let heartRateQualities = dataPoints.compactMap { $0.heartRateQuality }
        let spo2Qualities = dataPoints.compactMap { $0.spo2Quality }

        // Calculate averages
        let avgHR = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
        let avgSpO2 = spo2Values.isEmpty ? nil : spo2Values.reduce(0, +) / Double(spo2Values.count)
        let avgTemp = temperatures.isEmpty ? 0 : temperatures.reduce(0, +) / Double(temperatures.count)
        let avgBattery = batteries.isEmpty ? 0 : batteries.reduce(0, +) / Double(batteries.count)

        // Calculate ranges
        let minHR = heartRates.min()
        let maxHR = heartRates.max()
        let minSpO2 = spo2Values.min()
        let maxSpO2 = spo2Values.max()
        let minTemp = temperatures.min() ?? 0
        let maxTemp = temperatures.max() ?? 0

        // Calculate activity
        let totalActivity = dataPoints.reduce(0.0) { $0 + $1.movementIntensity }
        let totalGrinding = dataPoints.reduce(0) { $0 + ($1.grindingEvents ?? 0) }

        // Calculate quality averages
        let avgHRQuality = heartRateQualities.isEmpty ? 0 : heartRateQualities.reduce(0, +) / Double(heartRateQualities.count)
        let avgSpO2Quality = spo2Qualities.isEmpty ? 0 : spo2Qualities.reduce(0, +) / Double(spo2Qualities.count)

        return AggregatedMetrics(
            averageHeartRate: avgHR,
            averageSpO2: avgSpO2,
            averageTemperature: avgTemp,
            averageBattery: avgBattery,
            minHeartRate: minHR,
            maxHeartRate: maxHR,
            minSpO2: minSpO2,
            maxSpO2: maxSpO2,
            minTemperature: minTemp,
            maxTemperature: maxTemp,
            totalActivityIntensity: totalActivity,
            totalGrindingEvents: totalGrinding,
            heartRateQualityAverage: avgHRQuality,
            spo2QualityAverage: avgSpO2Quality,
            dataPointsCount: dataPoints.count,
            validHeartRateCount: heartRates.count,
            validSpO2Count: spo2Values.count
        )
    }

    private func extractMetricValue(from point: HistoricalDataPoint, metric: MetricType) -> Double? {
        switch metric {
        case .heartRate:
            return point.averageHeartRate
        case .spO2:
            return point.averageSpO2
        case .temperature:
            return point.averageTemperature
        case .battery:
            return Double(point.averageBattery)
        case .activity:
            return point.movementIntensity
        }
    }
}

// MARK: - Supporting Types

enum MetricType {
    case heartRate
    case spO2
    case temperature
    case battery
    case activity
}

// MARK: - Extensions for HistoricalViewModel Integration

extension HistoricalViewModel {
    /// Update metrics using background processing
    func updateMetricsAsync() async {
        guard let metrics = currentMetrics else { return }

        let processor = HistoricalDataProcessor()

        // Process in background
        let aggregated = await processor.aggregateMetrics(for: metrics.dataPoints, timeRange: metrics.timeRange)

        // Update UI on main thread
        await MainActor.run {
            self.cachedAggregations = aggregated
        }
    }

    /// Generate chart data using background processing
    func generateChartDataAsync(metric: MetricType) async -> [ChartDataPoint] {
        guard let metrics = currentMetrics else { return [] }

        let processor = HistoricalDataProcessor()
        return await processor.generateChartData(for: metrics.dataPoints, metric: metric)
    }
}

// MARK: - HistoricalViewModel Extension for Caching

extension HistoricalViewModel {
    // Storage for cached aggregations
    private static var cachedAggregationsKey: UInt8 = 0

    var cachedAggregations: HistoricalDataProcessor.AggregatedMetrics? {
        get {
            objc_getAssociatedObject(self, &Self.cachedAggregationsKey) as? HistoricalDataProcessor.AggregatedMetrics
        }
        set {
            objc_setAssociatedObject(self, &Self.cachedAggregationsKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // Computed properties using cached values
    var cachedAverageHeartRate: String {
        guard let cached = cachedAggregations, let avgHR = cached.averageHeartRate else {
            return "--"
        }
        return String(format: "%.0f", avgHR)
    }

    var cachedAverageSpO2: String {
        guard let cached = cachedAggregations, let avgSpO2 = cached.averageSpO2 else {
            return "--"
        }
        return String(format: "%.0f", avgSpO2)
    }

    var cachedAverageTemperature: String {
        guard let cached = cachedAggregations else {
            return "--"
        }
        return String(format: "%.1f", cached.averageTemperature)
    }

    var cachedDataQuality: String {
        guard let cached = cachedAggregations, cached.dataPointsCount > 0 else {
            return "--"
        }

        let totalValid = cached.validHeartRateCount + cached.validSpO2Count
        let totalPossible = cached.dataPointsCount * 2
        let quality = Double(totalValid) / Double(totalPossible) * 100

        return String(format: "%.0f%%", quality)
    }
}

// MARK: - Chart Data Point (if not already defined)

// Assuming ChartDataPoint is already defined in HistoricalViewModel.swift
// If not, uncomment below:
/*
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}
*/
