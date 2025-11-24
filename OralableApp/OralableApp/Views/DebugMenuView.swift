//
//  DebugMenuView.swift
//  OralableApp
//
//  Created by John A Cogan on 23/11/2025.
//


import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject var bleManager: OralableBLE
    @EnvironmentObject var sensorDataStore: SensorDataStore

    var body: some View {
        Form {
            Section(header: Text("BLE")) {
                Toggle("Simulate BLE Connection", isOn: $bleManager.isConnected)
                Toggle("Simulate Recording", isOn: $bleManager.isRecording)
            }

            Section(header: Text("Sensor Data")) {
                Button("Inject Mock Sensor Data") {
                    let mockDataBatch = SensorData.mockBatch()
                    // Store each mock data point
                    for mockData in mockDataBatch {
                        sensorDataStore.storeSensorData(mockData)
                    }
                }

                Button("Clear Sensor History") {
                    sensorDataStore.clearHistory()
                }
            }
        }
        .navigationTitle("Debug Menu")
    }
}
