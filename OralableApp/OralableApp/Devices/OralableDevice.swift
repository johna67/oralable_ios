//
//  OralableDevice.swift
//  OralableApp
//
//  Created: November 2024
//  UPDATED: November 29, 2025 (Day 4)
//  Fixed: Batch updates to prevent performance flooding (60+ UI updates/sec)
//  Fixed: Removed PPG validation to allow all values for debugging
//

import Foundation
import CoreBluetooth
import Combine

/// Oralable-specific BLE device implementation
class OralableDevice: NSObject, BLEDeviceProtocol {
    // MARK: - BLE Protocol Properties

    var deviceInfo: DeviceInfo
    var peripheral: CBPeripheral?

    // MARK: - Protocol Required Properties

    var deviceType: DeviceType { .oralable }
    var name: String { deviceInfo.name }
    var connectionState: DeviceConnectionState { deviceInfo.connectionState }
    var isConnected: Bool { peripheral?.state == .connected }
    var signalStrength: Int? { deviceInfo.signalStrength }
    var firmwareVersion: String? { nil }
    var hardwareVersion: String? { nil }

    var supportedSensors: [SensorType] {
        [.ppgRed, .ppgInfrared, .ppgGreen, .accelerometerX, .accelerometerY, .accelerometerZ, .temperature, .battery]
    }

    private let readingsSubject = PassthroughSubject<SensorReading, Never>()
    var sensorReadings: AnyPublisher<SensorReading, Never> {
        readingsSubject.eraseToAnyPublisher()
    }

    private let readingsBatchSubject = PassthroughSubject<[SensorReading], Never>()
    var sensorReadingsBatch: AnyPublisher<[SensorReading], Never> {
        readingsBatchSubject.eraseToAnyPublisher()
    }

    @Published var latestReadings: [SensorType: SensorReading] = [:]
    @Published var batteryLevel: Int?
    
    // MARK: - TGM Service & Characteristics
    
    private let tgmServiceUUID = CBUUID(string: "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
    private let sensorDataCharUUID = CBUUID(string: "3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E")
    // CORRECTED: 3A0FF002 is accelerometer data (154 bytes), not command
    private let ppgWaveformCharUUID = CBUUID(string: "3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E")  // Accelerometer (154 bytes)
    private let commandCharUUID = CBUUID(string: "3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E")      // Commands/Temperature (8 bytes)
    
    private var tgmService: CBService?
    private var sensorDataCharacteristic: CBCharacteristic?
    private var commandCharacteristic: CBCharacteristic?
    private var ppgWaveformCharacteristic: CBCharacteristic?
    
    // MARK: - Data Collection State
    
    private var isCollecting = false
    private var sessionStartTime: Date?
    
    // Continuations for async/await flow
    private var serviceDiscoveryContinuation: CheckedContinuation<Void, Error>?
    private var characteristicDiscoveryContinuation: CheckedContinuation<Void, Error>?
    private var notificationEnableContinuation: CheckedContinuation<Void, Error>?
    private var accelerometerNotificationContinuation: CheckedContinuation<Void, Error>?
    
    // MARK: - Statistics
    
    private var packetsReceived: Int = 0
    private var bytesReceived: Int = 0
    private var lastPacketTime: Date?
    private var ppgFrameCount: Int = 0
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        
        // Create device info
        self.deviceInfo = DeviceInfo(
            type: .oralable,
            name: peripheral.name ?? "Oralable",
            peripheralIdentifier: peripheral.identifier,
            connectionState: .disconnected,
            signalStrength: nil
        )
        
        super.init()
        
        Logger.shared.info("[OralableDevice] Initialized for '\(deviceInfo.name)'")
        Logger.shared.info("[OralableDevice] Using TGM Service UUID: \(tgmServiceUUID.uuidString)")
        
        peripheral.delegate = self
    }
    
    // MARK: - Service Discovery (Day 2: Async/await)
    
    func discoverServices() async throws {
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral("Peripheral is nil")
        }
        
        Logger.shared.info("[OralableDevice] 🔍 Starting service discovery...")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.serviceDiscoveryContinuation = continuation
            peripheral.discoverServices([tgmServiceUUID])
        }
    }
    
    func discoverCharacteristics() async throws {
        guard let service = tgmService else {
            throw DeviceError.serviceNotFound("TGM service not found")
        }
        
        Logger.shared.info("[OralableDevice] 🔍 Starting characteristic discovery...")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.characteristicDiscoveryContinuation = continuation
            peripheral?.discoverCharacteristics([
                sensorDataCharUUID,
                commandCharUUID,
                ppgWaveformCharUUID
            ], for: service)
        }
    }
    
    func enableNotifications() async throws {
        guard let peripheral = peripheral,
              let characteristic = sensorDataCharacteristic else {
            throw DeviceError.characteristicNotFound("Sensor data characteristic not found")
        }
        
        Logger.shared.info("[OralableDevice] 🔔 Enabling notifications on main characteristic...")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.notificationEnableContinuation = continuation
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    // Day 2: Enable accelerometer notifications (non-blocking)
    func enableAccelerometerNotifications() async {
        guard let peripheral = peripheral,
              let characteristic = ppgWaveformCharacteristic else {
            Logger.shared.warning("[OralableDevice] ⚠️ PPG Waveform characteristic not found for accelerometer")
            return
        }

        Logger.shared.info("[OralableDevice] 🔔 Enabling notifications on accelerometer characteristic...")

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.accelerometerNotificationContinuation = continuation
                peripheral.setNotifyValue(true, for: characteristic)
            }
            Logger.shared.info("[OralableDevice] ✅ Accelerometer notifications enabled")
        } catch {
            Logger.shared.warning("[OralableDevice] ⚠️ Failed to enable accelerometer notifications: \(error.localizedDescription)")
        }
    }

    // Enable temperature notifications on 3A0FF003
    func enableTemperatureNotifications() async {
        guard let peripheral = peripheral,
              let characteristic = commandCharacteristic else {
            Logger.shared.warning("[OralableDevice] ⚠️ Command characteristic not found for temperature")
            return
        }

        Logger.shared.info("[OralableDevice] 🔔 Enabling notifications on temperature characteristic (3A0FF003)...")
        peripheral.setNotifyValue(true, for: characteristic)
        Logger.shared.info("[OralableDevice] ✅ Temperature notifications enabled")
    }

    // MARK: - LED Configuration

    /// Configure PPG LED pulse amplitudes after connection
    func configurePPGLEDs() async throws {
        guard let peripheral = peripheral,
              let commandChar = commandCharacteristic else {
            Logger.shared.warning("[OralableDevice] ⚠️ Command characteristic not available for LED config")
            return
        }

        Logger.shared.info("[OralableDevice] 💡 Configuring PPG LEDs...")

        // LED pulse amplitude values (0x00 = off, 0xFF = max)
        // Start with moderate values to avoid saturation
        let irAmplitude: UInt8 = 0x60      // IR LED (register 0x24)
        let redAmplitude: UInt8 = 0x60     // Red LED (register 0x25)
        let greenAmplitude: UInt8 = 0x30   // Green LED (register 0x23)

        // Configure Green LED (LED1)
        let greenCommand = Data([0x23, greenAmplitude])
        peripheral.writeValue(greenCommand, for: commandChar, type: .withResponse)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

        // Configure IR LED (LED2)
        let irCommand = Data([0x24, irAmplitude])
        peripheral.writeValue(irCommand, for: commandChar, type: .withResponse)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Configure Red LED (LED3)
        let redCommand = Data([0x25, redAmplitude])
        peripheral.writeValue(redCommand, for: commandChar, type: .withResponse)
        try await Task.sleep(nanoseconds: 100_000_000)

        Logger.shared.info("[OralableDevice] ✅ PPG LEDs configured - IR:0x\(String(format: "%02X", irAmplitude)), Red:0x\(String(format: "%02X", redAmplitude)), Green:0x\(String(format: "%02X", greenAmplitude))")
    }

    // MARK: - Continuation Cleanup

    /// Cancel any pending continuations to prevent hangs on disconnect
    func cancelPendingContinuations() {
        if let continuation = serviceDiscoveryContinuation {
            continuation.resume(throwing: DeviceError.connectionLost)
            serviceDiscoveryContinuation = nil
            Logger.shared.info("[OralableDevice] Cancelled pending service discovery continuation")
        }
        if let continuation = characteristicDiscoveryContinuation {
            continuation.resume(throwing: DeviceError.connectionLost)
            characteristicDiscoveryContinuation = nil
            Logger.shared.info("[OralableDevice] Cancelled pending characteristic discovery continuation")
        }
        if let continuation = notificationEnableContinuation {
            continuation.resume(throwing: DeviceError.connectionLost)
            notificationEnableContinuation = nil
            Logger.shared.info("[OralableDevice] Cancelled pending notification enable continuation")
        }
        if let continuation = accelerometerNotificationContinuation {
            continuation.resume(throwing: DeviceError.connectionLost)
            accelerometerNotificationContinuation = nil
            Logger.shared.info("[OralableDevice] Cancelled pending accelerometer notification continuation")
        }
    }

    // MARK: - Data Collection Control

    func startDataCollection() async throws {
        guard let peripheral = peripheral else {
            throw DeviceError.invalidPeripheral("Peripheral is nil")
        }

        guard peripheral.state == .connected else {
            throw DeviceError.notConnected("Peripheral not connected")
        }
        
        Logger.shared.info("[OralableDevice] Starting data collection...")
        
        isCollecting = true
        sessionStartTime = Date()
        packetsReceived = 0
        bytesReceived = 0
        ppgFrameCount = 0
        
        Logger.shared.info("[OralableDevice] ✅ Data collection started")
    }
    
    func stopDataCollection() async throws {
        Logger.shared.info("[OralableDevice] Stopping data collection...")
        
        isCollecting = false
        
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.info("[OralableDevice] Session duration: \(String(format: "%.1f", duration))s")
            Logger.shared.info("[OralableDevice] Packets received: \(packetsReceived)")
            Logger.shared.info("[OralableDevice] Bytes received: \(bytesReceived)")
            Logger.shared.info("[OralableDevice] PPG frames: \(ppgFrameCount)")
        }
        
        sessionStartTime = nil
        
        Logger.shared.info("[OralableDevice] ✅ Data collection stopped")
    }

    // MARK: - Protocol Required Methods

    func connect() async throws {
        // Connection is handled by DeviceManager/BLECentralManager
        Logger.shared.info("[OralableDevice] Connect called - handled by BLE manager")
    }

    func disconnect() async {
        Logger.shared.info("[OralableDevice] Disconnect called")
    }

    func isAvailable() -> Bool {
        peripheral != nil
    }

    func startDataStream() async throws {
        try await startDataCollection()
    }

    func stopDataStream() async {
        try? await stopDataCollection()
    }

    func requestReading(for sensorType: SensorType) async throws -> SensorReading? {
        latestReadings[sensorType]
    }

    func parseData(_ data: Data, from characteristic: CBCharacteristic) -> [SensorReading] {
        // Parsing is handled internally by delegate methods
        []
    }

    func sendCommand(_ command: DeviceCommand) async throws {
        guard let peripheral = peripheral,
              let characteristic = commandCharacteristic else {
            throw DeviceError.characteristicNotFound("Command characteristic not found")
        }

        let commandData = command.rawValue.data(using: .utf8) ?? Data()
        peripheral.writeValue(commandData, for: characteristic, type: .withResponse)
    }

    func updateConfiguration(_ config: DeviceConfiguration) async throws {
        // Configuration updates handled via commands
        Logger.shared.info("[OralableDevice] Configuration update requested")
    }

    func updateDeviceInfo() async throws {
        Logger.shared.info("[OralableDevice] Device info update requested")
    }

    // MARK: - Data Parsing
    
    private func parseSensorData(_ data: Data) {
        let now = Date()

        // Update packet statistics
        packetsReceived += 1
        bytesReceived += data.count

        if let lastTime = lastPacketTime {
            let interval = now.timeIntervalSince(lastTime)
            #if DEBUG
            if interval > 0.2 {
                Logger.shared.debug("[OralableDevice] ⚠️ Large packet interval: \(String(format: "%.3f", interval))s")
            }
            #endif
        }
        lastPacketTime = now

        // Helper to read UInt32 little-endian
        func readUInt32(at offset: Int) -> UInt32? {
            guard offset + 3 < data.count else { return nil }
            return data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            }
        }

        // PPG packet format (from firmware docs):
        // Bytes 0-3: Frame counter (uint32_t)
        // Bytes 4+: 20 samples, each 12 bytes (Red, IR, Green as uint32_t)
        let frameCounter = readUInt32(at: 0) ?? 0
        let samplesPerFrame = 20  // CONFIG_PPG_SAMPLES_PER_FRAME (hardcoded)
        let sampleSizeBytes = 12  // 3 × uint32_t per sample

        #if DEBUG
        Logger.shared.debug("[OralableDevice] 📊 Frame #\(frameCounter) | Samples: \(samplesPerFrame) | Size: \(data.count) bytes")
        #endif

        // Verify packet size
        let expectedSize = 4 + (samplesPerFrame * sampleSizeBytes)  // 4 + 240 = 244
        guard data.count >= expectedSize else {
            Logger.shared.warning("[OralableDevice] ⚠️ Packet size mismatch: got \(data.count), expected \(expectedSize)")
            return
        }

        // Parse samples (start at byte 4, after frame counter)
        var readings: [SensorReading] = []
        let sampleDataStart = 4

        for i in 0..<samplesPerFrame {
            let sampleOffset = sampleDataStart + (i * sampleSizeBytes)

            guard sampleOffset + sampleSizeBytes <= data.count else {
                Logger.shared.warning("[OralableDevice] ⚠️ Sample \(i) exceeds data bounds")
                break
            }

            let sampleTimestamp = Date()

            // PPG Red (bytes 0-3 of sample)
            if let ppgRed = readUInt32(at: sampleOffset) {
                readings.append(SensorReading(
                    sensorType: .ppgRed,
                    value: Double(ppgRed),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: ppgRed > 10000 ? 0.9 : 0.1
                ))
            }

            // PPG IR (bytes 4-7 of sample)
            if let ppgIR = readUInt32(at: sampleOffset + 4) {
                readings.append(SensorReading(
                    sensorType: .ppgInfrared,
                    value: Double(ppgIR),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: ppgIR > 10000 ? 0.9 : 0.1
                ))
            }

            // PPG Green (bytes 8-11 of sample)
            if let ppgGreen = readUInt32(at: sampleOffset + 8) {
                readings.append(SensorReading(
                    sensorType: .ppgGreen,
                    value: Double(ppgGreen),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString,
                    quality: ppgGreen > 10000 ? 0.9 : 0.1
                ))
            }

            // NOTE: Temperature comes in separate 8-byte packets, not in PPG packets
        }

        // Batch update latestReadings ONCE after loop
        var latestByType: [SensorType: SensorReading] = [:]
        for reading in readings {
            latestByType[reading.sensorType] = reading
        }

        for (type, reading) in latestByType {
            latestReadings[type] = reading
        }

        // Emit batch for downstream consumers
        if !readings.isEmpty {
            readingsBatchSubject.send(readings)
            Logger.shared.info("[OralableDevice] 📤 Emitted batch: \(readings.count) readings, \(latestByType.count) unique types")

            ppgFrameCount += 1

            #if DEBUG
            if ppgFrameCount % 100 == 0 {
                Logger.shared.debug("[OralableDevice] 📊 PPG Frame #\(ppgFrameCount): \(readings.count) readings")
            }
            #endif
        }
    }

    // MARK: - Temperature Parsing (separate 8-byte packets)

    private func parseTemperature(_ data: Data) {
        // Temperature packet format (8 bytes):
        // Bytes 0-3: Frame counter
        // Bytes 4-5: Temperature (int16, centidegrees Celsius)
        guard data.count >= 6 else {
            Logger.shared.warning("[OralableDevice] ⚠️ Temperature packet too small: \(data.count) bytes")
            return
        }

        func readInt16(at offset: Int) -> Int16? {
            guard offset + 1 < data.count else { return nil }
            return data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: offset, as: Int16.self)
            }
        }

        let frameCounter = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
        }

        if let tempRaw = readInt16(at: 4) {
            let tempCelsius = Double(tempRaw) / 100.0

            if tempCelsius > -40 && tempCelsius < 85 {
                let reading = SensorReading(
                    sensorType: .temperature,
                    value: tempCelsius,
                    timestamp: Date(),
                    deviceId: peripheral?.identifier.uuidString
                )

                latestReadings[.temperature] = reading
                readingsBatchSubject.send([reading])

                Logger.shared.debug("[OralableDevice] 🌡️ Temperature: \(String(format: "%.2f", tempCelsius))°C (frame #\(frameCounter))")
            }
        }
    }

    // MARK: - Battery Parsing (4-byte packets)

    private func parseBatteryData(_ data: Data) {
        guard data.count >= 4 else {
            Logger.shared.warning("[OralableDevice] ⚠️ Battery packet too small: \(data.count) bytes")
            return
        }

        // Battery is Int32 in millivolts
        let millivolts = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: Int32.self)
        }

        // Convert to percentage (typical LiPo: 3.0V = 0%, 4.2V = 100%)
        let voltage = Double(millivolts) / 1000.0
        let percentage = min(100.0, max(0.0, (voltage - 3.0) / (4.2 - 3.0) * 100.0))

        Logger.shared.info("[OralableDevice] 🔋 Battery: \(millivolts)mV (\(String(format: "%.0f", percentage))%)")

        let reading = SensorReading(
            sensorType: .battery,
            value: percentage,
            timestamp: Date(),
            deviceId: peripheral?.identifier.uuidString
        )

        latestReadings[.battery] = reading
        readingsBatchSubject.send([reading])
    }

    private func parsePPGWaveform(_ data: Data) {
        // Accelerometer packet format (per firmware spec):
        // Bytes 0-3: Frame counter (UInt32)
        // Bytes 4+: 25 samples, each 6 bytes (X, Y, Z as Int16)
        // Total expected size: 4 + (25 * 6) = 154 bytes

        // Fixed values per firmware spec - accelerometer doesn't send config in header
        let sampleDataStart = 4              // Data starts after 4-byte frame counter
        let samplesPerFrame = 25             // CONFIG_ACC_SAMPLES_PER_FRAME = 25
        let sampleSizeBytes = 6              // 3 × Int16 (X, Y, Z) = 6 bytes per sample
        let expectedSize = sampleDataStart + (samplesPerFrame * sampleSizeBytes)  // 154 bytes

        #if DEBUG
        Logger.shared.debug("[OralableDevice] 🏃 Accelerometer packet | Size: \(data.count) bytes (expected: \(expectedSize))")
        #endif

        guard data.count >= sampleDataStart + sampleSizeBytes else {
            Logger.shared.warning("[OralableDevice] ⚠️ Accelerometer packet too small: \(data.count) bytes (need at least \(sampleDataStart + sampleSizeBytes))")
            return
        }

        // Helper to read Int16 little-endian
        func readInt16(at offset: Int) -> Int16? {
            guard offset + 1 < data.count else { return nil }
            return data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: offset, as: Int16.self)
            }
        }

        // Read frame counter for logging
        let frameCounter = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
        }

        var readings: [SensorReading] = []

        // Calculate actual number of samples we can parse
        let actualSamples = min(samplesPerFrame, (data.count - sampleDataStart) / sampleSizeBytes)

        for i in 0..<actualSamples {
            let sampleOffset = sampleDataStart + (i * sampleSizeBytes)
            
            guard sampleOffset + sampleSizeBytes <= data.count else {
                Logger.shared.warning("[OralableDevice] ⚠️ Waveform sample \(i) exceeds bounds")
                break
            }
            
            let sampleTimestamp = Date()
            
            // Accelerometer X (bytes 0-1)
            if let accelX = readInt16(at: sampleOffset) {
                readings.append(SensorReading(
                    sensorType: .accelerometerX,
                    value: Double(accelX),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString
                ))
            }
            
            // Accelerometer Y (bytes 2-3)
            if let accelY = readInt16(at: sampleOffset + 2) {
                readings.append(SensorReading(
                    sensorType: .accelerometerY,
                    value: Double(accelY),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString
                ))
            }
            
            // Accelerometer Z (bytes 4-5)
            if let accelZ = readInt16(at: sampleOffset + 4) {
                readings.append(SensorReading(
                    sensorType: .accelerometerZ,
                    value: Double(accelZ),
                    timestamp: sampleTimestamp,
                    deviceId: peripheral?.identifier.uuidString
                ))
            }
        }
        
        // DAY 4 PERFORMANCE FIX: Same batch update pattern as parseSensorData
        var latestByType: [SensorType: SensorReading] = [:]
        for reading in readings {
            latestByType[reading.sensorType] = reading
        }
        
        // Single batch update
        for (type, reading) in latestByType {
            latestReadings[type] = reading
        }
        
        // Emit batch
        if !readings.isEmpty {
            readingsBatchSubject.send(readings)

            // Log first sample values for debugging
            if let x = latestByType[.accelerometerX]?.value,
               let y = latestByType[.accelerometerY]?.value,
               let z = latestByType[.accelerometerZ]?.value {
                Logger.shared.info("[OralableDevice] 🏃 Accelerometer (frame #\(frameCounter)): X=\(Int(x)), Y=\(Int(y)), Z=\(Int(z)) | \(actualSamples) samples parsed")
            }
        } else {
            Logger.shared.warning("[OralableDevice] ⚠️ No accelerometer readings parsed from \(data.count) byte packet")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension OralableDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            Logger.shared.error("[OralableDevice] ❌ Service discovery failed: \(error.localizedDescription)")
            serviceDiscoveryContinuation?.resume(throwing: DeviceError.serviceNotFound("Service discovery failed: \(error.localizedDescription)"))
            serviceDiscoveryContinuation = nil
            return
        }

        guard let services = peripheral.services else {
            Logger.shared.error("[OralableDevice] ❌ No services found")
            serviceDiscoveryContinuation?.resume(throwing: DeviceError.serviceNotFound("No services found on peripheral"))
            serviceDiscoveryContinuation = nil
            return
        }
        
        Logger.shared.info("[OralableDevice] ✅ Discovered \(services.count) service(s)")
        
        // Find TGM service
        if let tgmSvc = services.first(where: { $0.uuid == tgmServiceUUID }) {
            self.tgmService = tgmSvc
            Logger.shared.info("[OralableDevice] ✅ TGM Service found: \(tgmSvc.uuid.uuidString)")
            serviceDiscoveryContinuation?.resume()
            serviceDiscoveryContinuation = nil
        } else {
            Logger.shared.error("[OralableDevice] ❌ TGM Service not found")
            serviceDiscoveryContinuation?.resume(throwing: DeviceError.serviceNotFound("TGM service UUID not found in discovered services"))
            serviceDiscoveryContinuation = nil
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            Logger.shared.error("[OralableDevice] ❌ Characteristic discovery failed: \(error.localizedDescription)")
            characteristicDiscoveryContinuation?.resume(throwing: DeviceError.characteristicNotFound("Characteristic discovery failed: \(error.localizedDescription)"))
            characteristicDiscoveryContinuation = nil
            return
        }

        guard let characteristics = service.characteristics else {
            Logger.shared.error("[OralableDevice] ❌ No characteristics found")
            characteristicDiscoveryContinuation?.resume(throwing: DeviceError.characteristicNotFound("No characteristics found in service"))
            characteristicDiscoveryContinuation = nil
            return
        }
        
        Logger.shared.info("[OralableDevice] ✅ Discovered \(characteristics.count) characteristic(s)")
        
        var foundCount = 0
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case sensorDataCharUUID:
                sensorDataCharacteristic = characteristic
                Logger.shared.info("[OralableDevice] ✅ Sensor Data characteristic found")
                foundCount += 1
                
            case commandCharUUID:
                commandCharacteristic = characteristic
                Logger.shared.info("[OralableDevice] ✅ Command characteristic found")
                foundCount += 1
                
            case ppgWaveformCharUUID:
                ppgWaveformCharacteristic = characteristic
                Logger.shared.info("[OralableDevice] ✅ PPG Waveform characteristic found")
                foundCount += 1
                
            default:
                Logger.shared.debug("[OralableDevice] Other characteristic: \(characteristic.uuid.uuidString)")
            }
        }
        
        if foundCount >= 1 {  // At minimum need sensor data characteristic
            Logger.shared.info("[OralableDevice] ✅ Found \(foundCount)/3 expected characteristics")
            characteristicDiscoveryContinuation?.resume()
            characteristicDiscoveryContinuation = nil
        } else {
            Logger.shared.error("[OralableDevice] ❌ Required characteristics not found")
            characteristicDiscoveryContinuation?.resume(throwing: DeviceError.characteristicNotFound("Required characteristics not found (found \(foundCount)/3)"))
            characteristicDiscoveryContinuation = nil
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.shared.error("[OralableDevice] ❌ Notification state update failed: \(error.localizedDescription)")

            // Resume appropriate continuation
            if characteristic.uuid == sensorDataCharUUID {
                notificationEnableContinuation?.resume(throwing: DeviceError.characteristicNotFound("Failed to enable sensor data notifications: \(error.localizedDescription)"))
                notificationEnableContinuation = nil
            } else if characteristic.uuid == ppgWaveformCharUUID {
                accelerometerNotificationContinuation?.resume(throwing: DeviceError.characteristicNotFound("Failed to enable accelerometer notifications: \(error.localizedDescription)"))
                accelerometerNotificationContinuation = nil
            }
            return
        }
        
        if characteristic.isNotifying {
            Logger.shared.info("[OralableDevice] ✅ Notifications enabled for \(characteristic.uuid.uuidString)")
            
            // Resume appropriate continuation
            if characteristic.uuid == sensorDataCharUUID {
                notificationEnableContinuation?.resume()
                notificationEnableContinuation = nil
            } else if characteristic.uuid == ppgWaveformCharUUID {
                accelerometerNotificationContinuation?.resume()
                accelerometerNotificationContinuation = nil
            }
        } else {
            Logger.shared.warning("[OralableDevice] ⚠️ Notifications disabled for \(characteristic.uuid.uuidString)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.shared.error("[OralableDevice] ❌ Value update error: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value, !data.isEmpty else {
            Logger.shared.warning("[OralableDevice] ⚠️ Empty data received")
            return
        }

        // Debug logging for all incoming packets
        Logger.shared.debug("[OralableDevice] 📦 Received \(data.count) bytes on characteristic: \(characteristic.uuid.uuidString.prefix(8))...")

        // Route to appropriate parser based on characteristic AND packet size
        switch characteristic.uuid {
        case sensorDataCharUUID:
            // Sensor data characteristic can have different packet types by size
            switch data.count {
            case 244:  // PPG packet: 4-byte frame counter + 20×12 bytes samples
                parseSensorData(data)

            case 4:  // Battery packet: 4 bytes as Int32 in millivolts
                parseBatteryData(data)

            case 6...8:  // Temperature packet: 4-byte frame counter + 2-byte temp (+ padding)
                parseTemperature(data)

            default:
                Logger.shared.debug("[OralableDevice] 📦 Unknown sensor packet size: \(data.count) bytes")
                // Try to parse as PPG if large enough
                if data.count > 100 {
                    parseSensorData(data)
                }
            }

        case ppgWaveformCharUUID:
            // 3A0FF002: Accelerometer data (154 bytes expected)
            if data.count == 154 {
                parsePPGWaveform(data)
            } else if data.count > 100 {
                // Try accelerometer parser for similar sizes
                parsePPGWaveform(data)
            } else {
                Logger.shared.warning("[OralableDevice] ⚠️ Unexpected packet size on 3A0FF002: \(data.count) bytes (expected 154)")
            }

        case commandCharUUID:
            // 3A0FF003: Temperature (8 bytes) and potentially battery (4 bytes)
            switch data.count {
            case 6...8:
                // Temperature data: 4-byte frame counter + 2-byte temp (+ optional padding)
                parseTemperature(data)

            case 4:
                // Battery data: 4 bytes as Int32 millivolts
                parseBatteryData(data)

            default:
                Logger.shared.debug("[OralableDevice] 📦 Data on 3A0FF003: \(data.count) bytes")
            }

        default:
            Logger.shared.debug("[OralableDevice] Data from unknown characteristic: \(characteristic.uuid.uuidString)")
        }
    }
}
