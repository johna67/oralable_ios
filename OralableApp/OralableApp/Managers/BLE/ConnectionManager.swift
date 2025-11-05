//
//  ConnectionManager.swift
//  OralableApp
//
//  Created by John A Cogan on 05/11/2025.
//


//
//  ConnectionManager.swift
//  OralableApp
//
//  Created: November 5, 2025
//  Manages BLE connection lifecycle
//

import Foundation
import CoreBluetooth
import Combine

/// Manages BLE device connection lifecycle
@MainActor
class ConnectionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var connectionState: CBPeripheralState = .disconnected
    @Published var isConnecting: Bool = false
    @Published var lastError: Error?
    
    // MARK: - Properties
    
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var connectionTimeout: Timer?
    
    // MARK: - Callbacks
    
    var onConnected: ((CBPeripheral) -> Void)?
    var onDisconnected: ((CBPeripheral, Error?) -> Void)?
    var onConnectionFailed: ((Error) -> Void)?
    
    // MARK: - Constants
    
    private let connectionTimeoutSeconds: TimeInterval = 10.0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Public Methods
    
    /// Connect to a peripheral
    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        
        isConnecting = true
        centralManager?.connect(peripheral, options: nil)
        
        // Start timeout timer
        connectionTimeout = Timer.scheduledTimer(
            withTimeInterval: connectionTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.handleConnectionTimeout()
        }
    }
    
    /// Disconnect from current peripheral
    func disconnect() {
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        
        if let peripheral = peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        
        isConnecting = false
    }
    
    /// Check if connected
    var isConnected: Bool {
        return peripheral?.state == .connected
    }
    
    // MARK: - Private Methods
    
    private func handleConnectionTimeout() {
        let error = NSError(
            domain: "com.oralable.connection",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]
        )
        
        lastError = error
        isConnecting = false
        onConnectionFailed?(error)
        
        disconnect()
    }
}

// MARK: - CBCentralManagerDelegate

extension ConnectionManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Handle Bluetooth state changes
        if central.state != .poweredOn && isConnecting {
            disconnect()
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        
        isConnecting = false
        connectionState = peripheral.state
        
        onConnected?(peripheral)
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        
        isConnecting = false
        lastError = error
        
        onConnectionFailed?(error ?? NSError(
            domain: "com.oralable.connection",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Failed to connect"]
        ))
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectionState = .disconnected
        lastError = error
        
        onDisconnected?(peripheral, error)
    }
}

// MARK: - CBPeripheralDelegate

extension ConnectionManager: CBPeripheralDelegate {
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        // Will be handled by other managers
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        // Will be handled by other managers
    }
}