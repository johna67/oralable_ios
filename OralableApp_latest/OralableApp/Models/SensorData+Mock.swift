import Foundation

extension SensorData {
    static func mockBatch(count: Int = 10) -> [SensorData] {
        let now = Date()
        return (0..<count).map { i in
            let timestamp = now.addingTimeInterval(Double(-i * 60))

            // Create mock PPG data
            let ppg = PPGData(
                red: Int32.random(in: 100000...300000),
                ir: Int32.random(in: 100000...300000),
                green: Int32.random(in: 100000...300000),
                timestamp: timestamp
            )

            // Create mock accelerometer data
            let accelerometer = AccelerometerData(
                x: Int16.random(in: -1000...1000),
                y: Int16.random(in: -1000...1000),
                z: Int16.random(in: -1000...1000),
                timestamp: timestamp
            )

            // Create mock temperature data
            let temperature = TemperatureData(
                celsius: Double.random(in: 35.5...37.5),
                timestamp: timestamp
            )

            // Create mock battery data
            let battery = BatteryData(
                percentage: Int.random(in: 60...100),
                timestamp: timestamp
            )

            // Create mock heart rate data
            let heartRate = HeartRateData(
                bpm: Double.random(in: 60...100),
                quality: Double.random(in: 0.7...1.0),
                timestamp: timestamp
            )

            // Create mock SpO2 data
            let spo2 = SpO2Data(
                percentage: Double.random(in: 95...100),
                quality: Double.random(in: 0.7...1.0),
                timestamp: timestamp
            )

            return SensorData(
                timestamp: timestamp,
                ppg: ppg,
                accelerometer: accelerometer,
                temperature: temperature,
                battery: battery,
                heartRate: heartRate,
                spo2: spo2
            )
        }
    }
}
