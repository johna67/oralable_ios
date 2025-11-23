import Foundation
import CoreBluetooth
import Combine

@MainActor
final class OralableBLE: NSObject, ObservableObject, BLEManagerProtocol {
    // MARK: - Discovered Device Info
    struct DiscoveredDeviceInfo: Identifiable {
        let id: UUID
        let name: String
        let peripheral: CBPeripheral
        var rssi: Int
        
        init(peripheral: CBPeripheral, name: String, rssi: Int) {
            self.id = peripheral.identifier
            self.peripheral = peripheral
            self.name = name
            self.rssi = rssi
        }
    }
    
    @Published var isConnected: Bool = false
    @Published var isRecording: Bool = false
    @Published var deviceName: String = "Unknown Device"
    @Published var isScanning: Bool = false
    @Published var deviceUUID: UUID?
    @Published var connectionState: String = "Disconnected"
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var discoveredDevicesInfo: [DiscoveredDeviceInfo] = []
    @Published var rssi: Int = 0
    
    // Device Status
    @Published var deviceState: DeviceStateResult?
    @Published var ppgChannelOrder: PPGChannelOrder = .standard
    @Published var discoveredServices: [String] = []
    @Published var packetsReceived: Int = 0
    @Published var logMessages: [LogMessage] = []
    @Published var lastError: String?
    
    // Biometric / Realtime Sensor Values
    @Published var heartRate: Int = 0
    @Published var spO2: Int = 0
    @Published var heartRateQuality: Double = 0.0
    @Published var batteryLevel: Double = 0.0
    @Published var firmwareVersion: String = "Unknown"
    
    // PPG Values
    @Published var ppgRedValue: Double = 0.0
    @Published var ppgIRValue: Double = 0.0
    @Published var ppgGreenValue: Double = 0.0
    
    // Accelerometer Values
    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var temperature: Double = 0.0
    
    // Historical data
    @Published var sensorDataHistory: [SensorData] = []
    @Published var heartRateHistory: CircularBuffer<HeartRateData> = CircularBuffer(capacity: 1000)
    @Published var spo2History: CircularBuffer<SpO2Data> = CircularBuffer(capacity: 1000)
    @Published var temperatureHistory: CircularBuffer<TemperatureData> = CircularBuffer(capacity: 1000)
    @Published var accelerometerHistory: CircularBuffer<AccelerometerData> = CircularBuffer(capacity: 5000)
    @Published var batteryHistory: CircularBuffer<BatteryData> = CircularBuffer(capacity: 1000)
    @Published var ppgHistory: CircularBuffer<PPGData> = CircularBuffer(capacity: 5000)
    
    var connectedDevice: CBPeripheral? { connectedPeripheral }

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        isScanning = true
        discoveredDevicesInfo.removeAll()
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func startRecording() {
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
    }
    
    func clearHistory() {
        sensorDataHistory.removeAll()
        heartRateHistory = CircularBuffer(capacity: 1000)
        spo2History = CircularBuffer(capacity: 1000)
        temperatureHistory = CircularBuffer(capacity: 1000)
        accelerometerHistory = CircularBuffer(capacity: 5000)
        batteryHistory = CircularBuffer(capacity: 1000)
        ppgHistory = CircularBuffer(capacity: 5000)
    }
    
    // MARK: - Mock for Previews
    static func mock() -> OralableBLE {
        let mock = OralableBLE()
        mock.deviceName = "Mock Device"
        mock.isConnected = true
        mock.heartRate = 72
        mock.spO2 = 98
        mock.batteryLevel = 85.0
        mock.temperature = 36.5
        return mock
    }
}

extension OralableBLE: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isConnected = (central.state == .poweredOn)
        if isConnected { startScanning() }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        let rssiValue = RSSI.intValue
        
        // Update or add to discoveredDevicesInfo
        if let index = discoveredDevicesInfo.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Update existing device's RSSI
            discoveredDevicesInfo[index].rssi = rssiValue
        } else {
            // Add new device
            let deviceInfo = DiscoveredDeviceInfo(peripheral: peripheral, name: name, rssi: rssiValue)
            discoveredDevicesInfo.append(deviceInfo)
        }
        
        // Keep legacy behavior for discoveredDevices
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectedPeripheral = peripheral
        deviceName = peripheral.name ?? "Connected Device"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
    }
}
