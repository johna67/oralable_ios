import Foundation

// MARK: - Time Range Selection
/// Represents the time period for viewing historical data
enum TimeRange: String, CaseIterable {
    case hour = "Hour"
    case day = "Day"
    case week = "Week"
    
    /// Returns the number of seconds for this time range
    var seconds: TimeInterval {
        switch self {
        case .hour: return 3600 // 1 hour
        case .day: return 86400 // 24 hours
        case .week: return 604800 // 7 days
        }
    }
    
    /// Returns the ideal number of data points to display for this range
    var idealDataPoints: Int {
        switch self {
        case .hour: return 60 // per minute
        case .day: return 24 // hourly
        case .week: return 7 // daily
        }
    }
}

// MARK: - Historical Data Point
/// Represents aggregated sensor data for a specific time point
struct HistoricalDataPoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    
    // PPG Metrics (averages)
    let avgIR: Double
    let avgRed: Double
    let avgGreen: Double
    
    // Accelerometer Metrics (averages)
    let avgAccelX: Double
    let avgAccelY: Double
    let avgAccelZ: Double
    let avgMagnitude: Double
    
    // Temperature Metrics
    let avgTemperature: Double
    let minTemperature: Double
    let maxTemperature: Double
    
    // Battery Metrics
    let avgBatteryLevel: Double
    
    // Activity Metrics
    let avgActivityLevel: Double
    
    // Grinding Metrics
    let grindingCount: Int
    let totalGrindingDuration: TimeInterval
    let avgGrindingIntensity: Double
    
    // Metadata
    let sampleCount: Int // Number of samples that went into this aggregation
}

// MARK: - Historical Metrics
/// Contains calculated metrics and trends for a time range
struct HistoricalMetrics: Codable {
    let timeRange: String
    let startDate: Date
    let endDate: Date
    
    // Overall Statistics
    let totalSamples: Int
    let dataPoints: [HistoricalDataPoint]
    
    // Trends (comparing latest to earliest in range)
    let temperatureTrend: Double // Positive = increasing, Negative = decreasing
    let batteryTrend: Double
    let activityTrend: Double
    
    // Summary Statistics
    let avgTemperature: Double
    let avgBatteryLevel: Double
    let totalGrindingEvents: Int
    let totalGrindingDuration: TimeInterval
}

// MARK: - Data Aggregator
/// Helper class to aggregate raw sensor data into time-based metrics
class HistoricalDataAggregator {
    
    /// Aggregates sensor data for a specific time range
    /// - Parameters:
    ///   - data: Array of SensorData to aggregate
    ///   - range: The time range to aggregate over
    ///   - endDate: The end date for the range (defaults to now)
    /// - Returns: HistoricalMetrics containing aggregated data
    static func aggregate(data: [SensorData],
                         for range: TimeRange,
                         endDate: Date = Date()) -> HistoricalMetrics {
        
        let startDate = endDate.addingTimeInterval(-range.seconds)
        
        // Filter data to the time range
        let filteredData = data.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
        
        guard !filteredData.isEmpty else {
            return createEmptyMetrics(range: range, startDate: startDate, endDate: endDate)
        }
        
        // Create time buckets for aggregation
        let bucketSize = range.seconds / Double(range.idealDataPoints)
        var buckets: [[SensorData]] = Array(repeating: [], count: range.idealDataPoints)
        
        // Distribute data into buckets
        for sensorData in filteredData {
            let timeSinceStart = sensorData.timestamp.timeIntervalSince(startDate)
            let bucketIndex = min(Int(timeSinceStart / bucketSize), range.idealDataPoints - 1)
            buckets[bucketIndex].append(sensorData)
        }
        
        // Create aggregated data points from buckets
        var dataPoints: [HistoricalDataPoint] = []
        
        for (index, bucket) in buckets.enumerated() {
            guard !bucket.isEmpty else { continue }
            
            let bucketTimestamp = startDate.addingTimeInterval(Double(index) * bucketSize + bucketSize / 2)
            let aggregatedPoint = aggregateBucket(bucket, timestamp: bucketTimestamp)
            dataPoints.append(aggregatedPoint)
        }
        
        // Calculate trends
        let temperatureTrend = calculateTrend(dataPoints.map { $0.avgTemperature })
        let batteryTrend = calculateTrend(dataPoints.map { $0.avgBatteryLevel })
        let activityTrend = calculateTrend(dataPoints.map { $0.avgActivityLevel })
        
        // Calculate summary statistics
        let avgTemperature = dataPoints.map { $0.avgTemperature }.reduce(0, +) / Double(max(dataPoints.count, 1))
        let avgBatteryLevel = dataPoints.map { $0.avgBatteryLevel }.reduce(0, +) / Double(max(dataPoints.count, 1))
        let totalGrindingEvents = dataPoints.map { $0.grindingCount }.reduce(0, +)
        let totalGrindingDuration = dataPoints.map { $0.totalGrindingDuration }.reduce(0, +)
        
        return HistoricalMetrics(
            timeRange: range.rawValue,
            startDate: startDate,
            endDate: endDate,
            totalSamples: filteredData.count,
            dataPoints: dataPoints,
            temperatureTrend: temperatureTrend,
            batteryTrend: batteryTrend,
            activityTrend: activityTrend,
            avgTemperature: avgTemperature,
            avgBatteryLevel: avgBatteryLevel,
            totalGrindingEvents: totalGrindingEvents,
            totalGrindingDuration: totalGrindingDuration
        )
    }
    
    /// Aggregates a bucket of sensor data into a single data point
    private static func aggregateBucket(_ bucket: [SensorData], timestamp: Date) -> HistoricalDataPoint {
        let count = Double(bucket.count)
        
        // PPG averages
        let avgIR = bucket.map { Double($0.ppg.ir) }.reduce(0, +) / count
        let avgRed = bucket.map { Double($0.ppg.red) }.reduce(0, +) / count
        let avgGreen = bucket.map { Double($0.ppg.green) }.reduce(0, +) / count
        
        // Accelerometer averages
        let avgAccelX = bucket.map { Double($0.accelerometer.x) }.reduce(0, +) / count
        let avgAccelY = bucket.map { Double($0.accelerometer.y) }.reduce(0, +) / count
        let avgAccelZ = bucket.map { Double($0.accelerometer.z) }.reduce(0, +) / count
        let avgMagnitude = bucket.map { $0.accelerometer.magnitude }.reduce(0, +) / count
        
        // Temperature statistics
        let temperatures = bucket.map { $0.temperature }
        let avgTemperature = temperatures.reduce(0, +) / count
        let minTemperature = temperatures.min() ?? 0
        let maxTemperature = temperatures.max() ?? 0
        
        // Battery average
        let avgBatteryLevel = bucket.map { Double($0.batteryLevel) }.reduce(0, +) / count
        
        // Activity average
        let avgActivityLevel = bucket.map { Double($0.activityLevel) }.reduce(0, +) / count
        
        // Grinding metrics
        let grindingCount = bucket.filter { $0.grinding.isActive }.count
        let totalGrindingDuration = bucket.map { $0.grinding.duration }.reduce(0, +)
        let grindingIntensities = bucket.filter { $0.grinding.isActive }.map { Double($0.grinding.intensity) }
        let avgGrindingIntensity = grindingIntensities.isEmpty ? 0 : grindingIntensities.reduce(0, +) / Double(grindingIntensities.count)
        
        return HistoricalDataPoint(
            timestamp: timestamp,
            avgIR: avgIR,
            avgRed: avgRed,
            avgGreen: avgGreen,
            avgAccelX: avgAccelX,
            avgAccelY: avgAccelY,
            avgAccelZ: avgAccelZ,
            avgMagnitude: avgMagnitude,
            avgTemperature: avgTemperature,
            minTemperature: minTemperature,
            maxTemperature: maxTemperature,
            avgBatteryLevel: avgBatteryLevel,
            avgActivityLevel: avgActivityLevel,
            grindingCount: grindingCount,
            totalGrindingDuration: totalGrindingDuration,
            avgGrindingIntensity: avgGrindingIntensity,
            sampleCount: bucket.count
        )
    }
    
    /// Calculates the trend (slope) of a series of values
    /// Returns positive for increasing trend, negative for decreasing
    private static func calculateTrend(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        
        let first = values.prefix(values.count / 3).reduce(0, +) / Double(max(values.count / 3, 1))
        let last = values.suffix(values.count / 3).reduce(0, +) / Double(max(values.count / 3, 1))
        
        return last - first
    }
    
    /// Creates empty metrics when no data is available
    private static func createEmptyMetrics(range: TimeRange, startDate: Date, endDate: Date) -> HistoricalMetrics {
        return HistoricalMetrics(
            timeRange: range.rawValue,
            startDate: startDate,
            endDate: endDate,
            totalSamples: 0,
            dataPoints: [],
            temperatureTrend: 0,
            batteryTrend: 0,
            activityTrend: 0,
            avgTemperature: 0,
            avgBatteryLevel: 0,
            totalGrindingEvents: 0,
            totalGrindingDuration: 0
        )
    }
}
