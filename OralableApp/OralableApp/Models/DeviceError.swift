//
//  DeviceError.swift
//  OralableApp
//
//  Created by John A Cogan on 10/11/2025.
//


//
//  DeviceError.swift
//  OralableApp
//
//  Created: November 10, 2025
//  Unified error definitions for all device operations
//

import Foundation

/// Unified device error type for all device-related errors
enum DeviceError: LocalizedError {
    // Connection errors
    case notConnected
    case connectionFailed(String)
    case connectionLost
    case disconnected
    case invalidPeripheral
    
    // BLE characteristic/service errors
    case characteristicNotFound(String)
    case serviceNotFound(String)
    
    // Data errors
    case dataCollectionFailed
    case invalidData
    case parsingError(String)
    
    // Device state errors
    case deviceNotAvailable
    case operationNotSupported
    case timeout
    
    // General errors
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPeripheral:
            return "Invalid or unavailable peripheral"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .connectionLost:
            return "Connection to device was lost"
        case .notConnected:
            return "Device is not connected"
        case .disconnected:
            return "Device disconnected"
        case .characteristicNotFound(let uuid):
            return "Characteristic not found: \(uuid)"
        case .serviceNotFound(let uuid):
            return "Service not found: \(uuid)"
        case .dataCollectionFailed:
            return "Failed to collect data from device"
        case .invalidData:
            return "Received invalid data from device"
        case .parsingError(let details):
            return "Data parsing error: \(details)"
        case .deviceNotAvailable:
            return "Device is not available"
        case .operationNotSupported:
            return "Operation not supported by this device"
        case .timeout:
            return "Operation timed out"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}
