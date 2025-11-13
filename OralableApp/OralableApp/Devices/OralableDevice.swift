//
//  OralableDevice.swift
//  OralableApp
//
//  CORRECTED: November 11, 2025
//  Fixed: SensorReading structure, protocol conformance, init signature
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable device implementation
class OralableDevice: NSObject, BLEDeviceProtocol, ObservableObject {
    
    // MARK: - BLE Service & Characteristic UUIDs
    
    private struct BLEConstants {
        // ✅ CORRECTED: TGM Service UUIDs (verified from nRF Connect 11/11/2025)
        static let serviceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
        
        // TGM Characteristics (from nRF Connect discovery)
        static let sensorDataCharacteristicUUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
        static let ppgWaveformCharacteristicUUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic003UUID = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic004UUID = CBUUID(string: "3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic005UUID = CBUUID(string: "3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic006UUID = CBUUID(string: "3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic007UUID = CBUUID(string: "3A0FF007-98C4-46B2-94AF-1AEE0FD4C48E")
        static let characteristic008UUID = CBUUID(string: "3A0FF008-98C4-46B2-94AF-1AEE0FD4C48E")
        
        // Standard BLE Services
        static let batteryServiceUUID = CBUUID(string: "180F")
        static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
        static let deviceInfoServiceUUID = CBUUID(string: "180A")
        static let firmwareVersionCharacteristicUUID = CBUUID(string: "2A26")
        static let hardwareVersionCharacteristicUUID = CBUUID(string: "2A27")
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var deviceInfo: DeviceInfo
    let deviceType: DeviceType = .oralable
    var name: String
    weak var peripheral: CBPeripheral?
    
    @Published private(set) var connectionState: DeviceConnectionState = .disconnected
    @Published private(set) var signalStrength: Int?
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var firmwareVersion: String?
    @Published private(set) var hardwareVersion: String?
    
    @Published private(set) var latestReadings: [SensorType: SensorReading] = [:]
    
    // MARK: - Sensor Data
    
    private let sensorReadingsSubject = PassthroughSubject<SensorReading, Never>()
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        sensorReadingsSubject.eraseToAnyPublisher()
    }
    
    let supportedSensors: [SensorType] = [
        .ppgRed,
        .ppgInfrared,
        .ppgGreen,
        .accelerometerX,
        .accelerometerY,
        .accelerometerZ,
        .temperature,
        .battery
    ]
    
    var isConnected: Bool {
        connectionState == .connected
    }
    
    // MARK: - Private Properties
    
    private var configuration: DeviceConfiguration = .defaultOralable
    private var isStreaming = false
    private var sensorDataCharacteristic: CBCharacteristic?
    private var ppgWaveformCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?
    private var cancellables = Set<AnyCancellable>()

    // Connection continuation for async/await
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral, deviceInfo: DeviceInfo? = nil) {
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Oralable Device"
        self.deviceInfo = deviceInfo ?? DeviceInfo(
            type: .oralable,
            name: peripheral.name ?? "Oralable Device",
            peripheralIdentifier: peripheral.identifier,
            connectionState: .disconnected
        )
        
        super.init()
        peripheral.delegate = self
        
        print("🏭 [OralableDevice] Initialized for '\(name)'")
        print("🏭 [OralableDevice] Using TGM Service UUID: \(BLEConstants.serviceUUID.uuidString)")
    }
    
    // MARK: - Connection Management
    
    func connect() async throws {
        guard let peripheral = peripheral else {
            print("❌ [OralableDevice] No peripheral available")
            throw DeviceError.invalidPeripheral
        }

        print("\n🔌 [OralableDevice] connect() called")
        print("🔌 [OralableDevice] Peripheral state: \(peripheral.state.rawValue)")

        connectionState = .connecting
        deviceInfo.connectionState = .connecting

        print("🔌 [OralableDevice] Discovering services...")

        // Use continuation to properly wait for service/characteristic discovery
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation

            peripheral.discoverServices([
                BLEConstants.serviceUUID,
                BLEConstants.batteryServiceUUID,
                BLEConstants.deviceInfoServiceUUID
            ])

            // Timeout after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if let cont = self?.connectionContinuation {
                    self?.connectionContinuation = nil
                    cont.resume(throwing: DeviceError.timeout)
                    print("⏱️ [OralableDevice] Connection timeout - service discovery took too long")
                }
            }
        }

        print("✅ [OralableDevice] Service discovery complete, device ready")
    }
    
    func disconnect() async {
        print("\n🔌 [OralableDevice] disconnect() called")
        
        connectionState = .disconnecting
        deviceInfo.connectionState = .disconnecting
        isStreaming = false
        
        if let characteristic = sensorDataCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        if let characteristic = ppgWaveformCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        connectionState = .disconnected
        deviceInfo.connectionState = .disconnected
        print("🔌 [OralableDevice] Disconnected")
    }
    
    func isAvailable() -> Bool {
        guard let peripheral = peripheral else { return false }
        return peripheral.state == .connected || peripheral.state == .connecting
    }
    
    // MARK: - Data Operations
    
    func startDataStream() async throws {
        print("\n📊 [OralableDevice] startDataStream() called")
        
        guard isConnected else {
            print("❌ [OralableDevice] Not connected")
            throw DeviceError.notConnected
        }
        
        if let characteristic = sensorDataCharacteristic {
            print("📊 [OralableDevice] Enabling sensor data notifications")
            peripheral?.setNotifyValue(true, for: characteristic)
            isStreaming = true
            print("✅ [OralableDevice] Sensor data notifications enabled")
        } else {
            print("❌ [OralableDevice] Sensor data characteristic not found")
            throw DeviceError.characteristicNotFound("Sensor Data")
        }
        
        if let characteristic = ppgWaveformCharacteristic {
            print("📊 [OralableDevice] Enabling PPG waveform notifications")
            peripheral?.setNotifyValue(true, for: characteristic)
            print("✅ [OralableDevice] PPG waveform notifications enabled")
        }
    }
    
    func stopDataStream() async {
        print("\n📊 [OralableDevice] stopDataStream() called")
        
        if let characteristic = sensorDataCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        if let characteristic = ppgWaveformCharacteristic {
            peripheral?.setNotifyValue(false, for: characteristic)
        }
        
        isStreaming = false
        print("✅ [OralableDevice] Data streaming stopped")
    }
    
    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard supportedSensors.contains(sensorType) else {
            throw DeviceError.operationNotSupported
        }
        
        return latestReadings[sensorType]
    }
    
    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        print("\n📦 [OralableDevice] parseData called")
        print("📦 [OralableDevice] Characteristic: \(characteristic.uuid.uuidString)")
        print("📦 [OralableDevice] Data length: \(data.count) bytes")

        // Route based on known characteristic UUIDs
        if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
            print("📦 [OralableDevice] Parsing PPG sensor data")
            return parseSensorData(data)
        } else if characteristic.uuid == BLEConstants.ppgWaveformCharacteristicUUID {
            print("📦 [OralableDevice] Parsing accelerometer waveform data")
            return parsePPGWaveform(data)
        } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
            print("📦 [OralableDevice] Parsing battery level data")
            return parseBatteryData(data)
        }

        // For unknown characteristics, try to infer based on data length
        switch data.count {
        case 4:
            print("📦 [OralableDevice] Detected 4-byte packet, parsing as battery voltage")
            return parseBatteryData(data)
        case 8:
            print("📦 [OralableDevice] Detected 8-byte packet, parsing as temperature")
            return parseTemperatureData(data)
        case 244:
            print("📦 [OralableDevice] Detected 244-byte packet, parsing as PPG data")
            return parseSensorData(data)
        case 154...156:
            print("📦 [OralableDevice] Detected 154-156 byte packet, parsing as accelerometer data")
            return parsePPGWaveform(data)
        default:
            print("⚠️ [OralableDevice] Unknown characteristic UUID and unrecognized data length: \(data.count) bytes")
            return []
        }
    }
    
    // MARK: - Device Control
    
    func sendCommand(_ command: DeviceCommand) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        guard let characteristic = controlCharacteristic else {
            throw DeviceError.characteristicNotFound("Control")
        }
        
        let commandData = command.rawValue.data(using: .utf8) ?? Data()
        peripheral?.writeValue(commandData, for: characteristic, type: .withResponse)
    }
    
    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        if config.samplingRate != configuration.samplingRate {
            try await sendCommand(.setSamplingRate(Hz: config.samplingRate))
        }
        
        let toEnable = config.enabledSensors.subtracting(configuration.enabledSensors)
        let toDisable = configuration.enabledSensors.subtracting(config.enabledSensors)
        
        for sensor in toEnable {
            try await sendCommand(.enableSensor(sensor))
        }
        
        for sensor in toDisable {
            try await sendCommand(.disableSensor(sensor))
        }
        
        self.configuration = config
    }
    
    func updateDeviceInfo() async throws {
        guard isConnected else {
            throw DeviceError.notConnected
        }
        
        // Request battery level and firmware version
        try await sendCommand(.requestBatteryLevel)
        try await sendCommand(.requestFirmwareVersion)
    }
    
    // MARK: - Data Parsing
    
    private func parseSensorData(_ data: Data) -> [SensorReading] {
        // Based on TGM firmware spec:
        // 244 bytes = PPG data format
        // Bytes 0-3: frame counter (uint32)
        // Then 20 samples of 12 bytes each:
        //   - Bytes 0-3: Red (int32)
        //   - Bytes 4-7: IR (int32)
        //   - Bytes 8-11: Green (int32)

        guard data.count >= 244 else {
            print("⚠️ [OralableDevice] Insufficient data for PPG parsing: \(data.count) bytes")
            return []
        }

        var readings: [SensorReading] = []
        let timestamp = Date()
        let deviceId = peripheral?.identifier.uuidString

        // Parse frame counter
        let frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        print("📦 [OralableDevice] PPG Frame #\(frameCounter)")

        // Arrays to collect all samples for batch processing
        var redSamples: [Int32] = []
        var irSamples: [Int32] = []
        var greenSamples: [Int32] = []

        // Parse 20 PPG samples
        for i in 0..<20 {
            let offset = 4 + (i * 12) // Skip frame counter, then 12 bytes per sample

            let red = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int32.self) }
            let ir = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: Int32.self) }
            let green = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 8, as: Int32.self) }

            redSamples.append(red)
            irSamples.append(ir)
            greenSamples.append(green)
        }

        // Create sensor readings for each sample
        // Note: We send individual readings but also log summary stats
        let avgRed = Double(redSamples.reduce(0, +)) / Double(redSamples.count)
        let avgIR = Double(irSamples.reduce(0, +)) / Double(irSamples.count)
        let avgGreen = Double(greenSamples.reduce(0, +)) / Double(greenSamples.count)

        print("📊 [OralableDevice] PPG Averages - Red: \(Int(avgRed)), IR: \(Int(avgIR)), Green: \(Int(avgGreen))")

        // Send readings for each sample to maintain high temporal resolution
        for i in 0..<20 {
            let sampleTimestamp = timestamp.addingTimeInterval(Double(i) * 0.02) // 50Hz = 20ms between samples

            readings.append(SensorReading(
                sensorType: .ppgRed,
                value: Double(redSamples[i]),
                timestamp: sampleTimestamp,
                deviceId: deviceId,
                quality: redSamples[i] > 0 ? 0.9 : 0.0
            ))

            readings.append(SensorReading(
                sensorType: .ppgInfrared,
                value: Double(irSamples[i]),
                timestamp: sampleTimestamp,
                deviceId: deviceId,
                quality: irSamples[i] > 0 ? 0.9 : 0.0
            ))

            readings.append(SensorReading(
                sensorType: .ppgGreen,
                value: Double(greenSamples[i]),
                timestamp: sampleTimestamp,
                deviceId: deviceId,
                quality: greenSamples[i] > 0 ? 0.9 : 0.0
            ))
        }

        // Send all readings through the publisher for downstream processing
        for reading in readings {
            sensorReadingsSubject.send(reading)
        }

        // Update latest readings with most recent sample
        if let lastRed = readings.last(where: { $0.sensorType == .ppgRed }) {
            latestReadings[.ppgRed] = lastRed
        }
        if let lastIR = readings.last(where: { $0.sensorType == .ppgInfrared }) {
            latestReadings[.ppgInfrared] = lastIR
        }
        if let lastGreen = readings.last(where: { $0.sensorType == .ppgGreen }) {
            latestReadings[.ppgGreen] = lastGreen
        }

        print("✅ [OralableDevice] Parsed \(readings.count) PPG sensor readings (20 samples × 3 channels)")
        return readings
    }
    
    private func parsePPGWaveform(_ data: Data) -> [SensorReading] {
        // Based on TGM firmware spec:
        // 154-156 bytes = Accelerometer data format
        // Bytes 0-3: frame counter (uint32)
        // Then 25 samples of 6 bytes each:
        //   - Bytes 0-1: X (int16)
        //   - Bytes 2-3: Y (int16)
        //   - Bytes 4-5: Z (int16)

        guard data.count >= 154 else {
            print("⚠️ [OralableDevice] Insufficient data for accelerometer parsing: \(data.count) bytes")
            return []
        }

        var readings: [SensorReading] = []
        let timestamp = Date()
        let deviceId = peripheral?.identifier.uuidString

        // Parse frame counter
        let frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        print("📦 [OralableDevice] Accelerometer Frame #\(frameCounter)")

        // Arrays to collect all samples
        var xSamples: [Int16] = []
        var ySamples: [Int16] = []
        var zSamples: [Int16] = []

        // Parse 25 accelerometer samples
        for i in 0..<25 {
            let offset = 4 + (i * 6) // Skip frame counter, then 6 bytes per sample

            let x = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: Int16.self) }
            let y = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 2, as: Int16.self) }
            let z = data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: Int16.self) }

            xSamples.append(x)
            ySamples.append(y)
            zSamples.append(z)
        }

        // Convert raw accelerometer values to g-force (assuming typical accelerometer scale)
        // Most accelerometers use a scale factor, typically ±2g, ±4g, etc.
        // For now, we'll use a typical conversion factor
        let scaleFactor = 1.0 / 16384.0 // Typical for ±2g range on many sensors

        // Log summary statistics
        let avgX = Double(xSamples.reduce(0, +)) / Double(xSamples.count) * scaleFactor
        let avgY = Double(ySamples.reduce(0, +)) / Double(ySamples.count) * scaleFactor
        let avgZ = Double(zSamples.reduce(0, +)) / Double(zSamples.count) * scaleFactor

        print("📊 [OralableDevice] Accel Averages - X: \(String(format: "%.3f", avgX))g, Y: \(String(format: "%.3f", avgY))g, Z: \(String(format: "%.3f", avgZ))g")

        // Send readings for each sample to maintain high temporal resolution
        for i in 0..<25 {
            let sampleTimestamp = timestamp.addingTimeInterval(Double(i) * 0.02) // 50Hz = 20ms between samples

            readings.append(SensorReading(
                sensorType: .accelerometerX,
                value: Double(xSamples[i]) * scaleFactor,
                timestamp: sampleTimestamp,
                deviceId: deviceId,
                quality: 0.95
            ))

            readings.append(SensorReading(
                sensorType: .accelerometerY,
                value: Double(ySamples[i]) * scaleFactor,
                timestamp: sampleTimestamp,
                deviceId: deviceId,
                quality: 0.95
            ))

            readings.append(SensorReading(
                sensorType: .accelerometerZ,
                value: Double(zSamples[i]) * scaleFactor,
                timestamp: sampleTimestamp,
                deviceId: deviceId,
                quality: 0.95
            ))
        }

        // Send all readings through the publisher for downstream processing
        for reading in readings {
            sensorReadingsSubject.send(reading)
        }

        // Update latest readings with most recent sample
        if let lastX = readings.last(where: { $0.sensorType == .accelerometerX }) {
            latestReadings[.accelerometerX] = lastX
        }
        if let lastY = readings.last(where: { $0.sensorType == .accelerometerY }) {
            latestReadings[.accelerometerY] = lastY
        }
        if let lastZ = readings.last(where: { $0.sensorType == .accelerometerZ }) {
            latestReadings[.accelerometerZ] = lastZ
        }

        print("✅ [OralableDevice] Parsed \(readings.count) accelerometer readings (25 samples × 3 axes)")
        return readings
    }
    
    private func parseBatteryData(_ data: Data) -> [SensorReading] {
        // Based on TGM firmware spec:
        // Battery voltage is sent as int32 (4 bytes) in millivolts (mV)

        guard data.count >= 4 else {
            print("⚠️ [OralableDevice] Insufficient data for battery parsing: \(data.count) bytes")
            return []
        }

        let batteryVoltage = data.withUnsafeBytes { $0.load(as: Int32.self) }
        let voltageInVolts = Double(batteryVoltage) / 1000.0 // Convert mV to V

        // Estimate battery percentage based on typical Li-Ion voltage curve
        // Fully charged: ~4.2V, Discharged: ~3.0V
        let percentage = min(100, max(0, ((voltageInVolts - 3.0) / 1.2) * 100))
        self.batteryLevel = Int(percentage)

        let reading = SensorReading(
            sensorType: .battery,
            value: percentage,
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString,
            quality: 1.0,
            metadata: ["voltage_v": voltageInVolts, "voltage_mv": Double(batteryVoltage)]
        )

        latestReadings[.battery] = reading
        sensorReadingsSubject.send(reading)

        print("🔋 [OralableDevice] Battery: \(String(format: "%.2f", voltageInVolts))V (\(Int(percentage))%)")
        return [reading]
    }

    private func parseTemperatureData(_ data: Data) -> [SensorReading] {
        // Based on TGM firmware spec:
        // Bytes 0-3: frame counter (uint32)
        // Bytes 4-5: temperature as int16 in centi-degrees Celsius (1/100 degree)
        // Example: 2137 = 21.37°C

        guard data.count >= 8 else {
            print("⚠️ [OralableDevice] Insufficient data for temperature parsing: \(data.count) bytes")
            return []
        }

        let frameCounter = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        let tempCentiDegrees = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int16.self) }
        let temperatureCelsius = Double(tempCentiDegrees) / 100.0

        let reading = SensorReading(
            sensorType: .temperature,
            value: temperatureCelsius,
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString,
            quality: 0.95,
            metadata: ["frame": Double(frameCounter)]
        )

        latestReadings[.temperature] = reading
        sensorReadingsSubject.send(reading)

        print("🌡️ [OralableDevice] Temperature Frame #\(frameCounter): \(String(format: "%.2f", temperatureCelsius))°C")
        return [reading]
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("\n🔍 [OralableDevice] didDiscoverServices")
        
        if let error = error {
            print("❌ [OralableDevice] Service discovery error: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("⚠️ [OralableDevice] No services found")
            return
        }
        
        print("✅ [OralableDevice] Discovered \(services.count) services:")
        for service in services {
            print("   - \(service.uuid.uuidString)")
            
            if service.uuid == BLEConstants.serviceUUID {
                print("🔍 [OralableDevice] Discovering characteristics for TGM Service...")
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid == BLEConstants.batteryServiceUUID {
                print("🔍 [OralableDevice] Discovering characteristics for Battery Service...")
                peripheral.discoverCharacteristics([BLEConstants.batteryLevelCharacteristicUUID], for: service)
            } else if service.uuid == BLEConstants.deviceInfoServiceUUID {
                print("🔍 [OralableDevice] Discovering characteristics for Device Info Service...")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("\n🔍 [OralableDevice] didDiscoverCharacteristicsFor service: \(service.uuid.uuidString)")
        
        // ✅ NEW CODE
        if let sensorChar = sensorDataCharacteristic {
            print("🔔 [OralableDevice] Auto-enabling notifications...")
            peripheral.setNotifyValue(true, for: sensorChar)
            isStreaming = true
        }

        if let ppgChar = ppgWaveformCharacteristic {
            print("🔔 [OralableDevice] Auto-enabling notifications...")
            peripheral.setNotifyValue(true, for: ppgChar)
        }
        
        if let error = error {
            print("❌ [OralableDevice] Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("⚠️ [OralableDevice] No characteristics found")
            return
        }
        
        print("✅ [OralableDevice] Discovered \(characteristics.count) characteristics:")
        for characteristic in characteristics {
            print("   - \(characteristic.uuid.uuidString)")
            print("     Properties: \(characteristic.properties)")
            
            if characteristic.uuid == BLEConstants.sensorDataCharacteristicUUID {
                sensorDataCharacteristic = characteristic
                print("✅ [OralableDevice] Found sensor data characteristic")
            } else if characteristic.uuid == BLEConstants.ppgWaveformCharacteristicUUID {
                ppgWaveformCharacteristic = characteristic
                print("✅ [OralableDevice] Found PPG waveform characteristic")
            } else if characteristic.uuid == BLEConstants.characteristic005UUID ||
                      characteristic.uuid == BLEConstants.characteristic006UUID {
                controlCharacteristic = characteristic
                print("✅ [OralableDevice] Found control characteristic")
            } else if characteristic.uuid == BLEConstants.batteryLevelCharacteristicUUID {
                print("🔋 [OralableDevice] Reading battery level...")
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == BLEConstants.firmwareVersionCharacteristicUUID {
                print("📱 [OralableDevice] Reading firmware version...")
                peripheral.readValue(for: characteristic)
            }
        }
        
        if sensorDataCharacteristic != nil {
            connectionState = .connected
            deviceInfo.connectionState = .connected
            print("✅ [OralableDevice] Device fully connected and ready")

            // Resume the connection continuation now that discovery is complete
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume()
                print("✅ [OralableDevice] Connection continuation resumed")
            }
        } else {
            // If required characteristic not found, fail the connection
            if let continuation = connectionContinuation {
                connectionContinuation = nil
                continuation.resume(throwing: DeviceError.characteristicNotFound("Sensor data characteristic not found"))
                print("❌ [OralableDevice] Required characteristic not found")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ [OralableDevice] Value update error: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("⚠️ [OralableDevice] No data received")
            return
        }
        
        print("📨 [OralableDevice] Data received from \(characteristic.uuid.uuidString) (\(data.count) bytes)")
        
        let readings = parseData(data, from: characteristic)
        
        for reading in readings {
            latestReadings[reading.sensorType] = reading
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ [OralableDevice] Notification state error: \(error.localizedDescription)")
            return
        }
        
        print("🔔 [OralableDevice] Notification state changed for \(characteristic.uuid.uuidString)")
        print("🔔 [OralableDevice] Is notifying: \(characteristic.isNotifying)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ [OralableDevice] Write error: \(error.localizedDescription)")
            return
        }
        
        print("✅ [OralableDevice] Write successful for \(characteristic.uuid.uuidString)")
    }
}
