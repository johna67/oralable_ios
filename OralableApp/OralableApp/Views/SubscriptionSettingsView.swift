//
//  SubscriptionSettingsView.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


import SwiftUI
import AuthenticationServices

struct SubscriptionSettingsView: View {
    @ObservedObject var ble: OralableBLE
    @Binding var selectedMode: AppMode?
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSignOutAlert = false
    @State private var showLogs = false
    @State private var showSubscriptionInfo = false
    @State private var showAppleIDDebug = false
    
    var body: some View {
        List {
            // Account Section
            Section("Account") {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.userFullName ?? "User")
                            .font(.headline)
                        if let email = authManager.userEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("Apple ID")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                Button(action: { showSignOutAlert = true }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .foregroundColor(.red)
                }
            }
            
            // Subscription Section
            Section("Subscription") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Plan")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(subscriptionManager.currentTier.displayName)
                                .font(.headline)
                            if subscriptionManager.currentTier == .paid {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    Spacer()
                    if subscriptionManager.currentTier == .basic {
                        Button("Upgrade") {
                            showSubscriptionInfo = true
                        }
                        .font(.subheadline)
                    }
                }
                
                Button(action: { showSubscriptionInfo = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("View Plans")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // PPG Configuration Section (Debug)
            if ble.isConnected {
                Section("PPG Configuration (Debug)") {
                    Picker("Channel Order", selection: $ble.ppgChannelOrder) {
                        ForEach(PPGChannelOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("If PPG values seem random or mixed up, try different channel orders to find the correct one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Connection Section
            Section("Device Connection") {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ble.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(ble.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(ble.isConnected ? .green : .red)
                    }
                }
                
                if ble.isConnected {
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(ble.deviceName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Battery")
                        Spacer()
                        Text("\(ble.sensorData.batteryLevel)%")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { ble.disconnect() }) {
                        HStack {
                            Image(systemName: "link.slash")
                            Text("Disconnect")
                        }
                        .foregroundColor(.orange)
                    }
                } else {
                    Button(action: { ble.toggleScanning() }) {
                        HStack {
                            Image(systemName: ble.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right")
                            Text(ble.isScanning ? "Stop Scanning" : "Start Scanning")
                        }
                    }
                }
            }
            
            // Logs Section
            Section("Diagnostics") {
                Button(action: { showLogs = true }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Logs")
                        Spacer()
                        Text("\(ble.logMessages.count)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { showAppleIDDebug = true }) {
                    HStack {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                        Text("Apple ID Debug")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: { ble.logMessages.removeAll() }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Logs")
                    }
                    .foregroundColor(.red)
                }
            }
            
            // App Mode Section
            Section("App Mode") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Subscription Mode")
                            .font(.headline)
                    }
                }
                
                Button(action: {
                    selectedMode = nil
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Change Mode")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }
                
                if ble.isConnected {
                    HStack {
                        Text("Firmware Version")
                        Spacer()
                        Text(ble.sensorData.firmwareVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Device UUID")
                        Spacer()
                        Text(String(format: "%016llX", ble.sensorData.deviceUUID))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://github.com/johna67/tgm_firmware")!) {
                    HStack {
                        Text("GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showLogs) {
            BLELogsView(logs: ble.logMessages)
        }
        .sheet(isPresented: $showSubscriptionInfo) {
            SubscriptionInfoView()
        }
        .sheet(isPresented: $showAppleIDDebug) {
            AppleIDDebugView()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
                selectedMode = nil
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access subscription features.")
        }
    }
}

// MARK: - Subscription Info View

struct SubscriptionInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isUpgrading = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Choose Your Plan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Unlock premium features and get the most out of your device")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Subscription Tiers
                    VStack(spacing: 16) {
                        // Basic Tier
                        SubscriptionTierCard(
                            tier: .basic,
                            isCurrentTier: subscriptionManager.currentTier == .basic,
                            action: {
                                // Already on basic, no action needed
                            }
                        )
                        
                        // Premium Tier
                        SubscriptionTierCard(
                            tier: .paid,
                            isCurrentTier: subscriptionManager.currentTier == .paid,
                            action: {
                                upgradeToPremium()
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Footer
                    VStack(spacing: 12) {
                        Text("All plans include:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureBullet(text: "Secure data encryption")
                            FeatureBullet(text: "Regular firmware updates")
                            FeatureBullet(text: "Customer support")
                        }
                        .padding(.horizontal, 32)
                    }
                    .padding(.top)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Success!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You've been upgraded to Premium! Enjoy all the premium features.")
            }
            .disabled(isUpgrading)
            .overlay {
                if isUpgrading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
    }
    
    private func upgradeToPremium() {
        guard subscriptionManager.currentTier != .paid else { return }

        isUpgrading = true

        #if DEBUG
        // In debug mode, simulate purchase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            subscriptionManager.simulatePurchase()
            isUpgrading = false
            showSuccessAlert = true
        }
        #else
        // In production, would use actual StoreKit purchase
        Task {
            do {
                guard let product = subscriptionManager.monthlyProduct else {
                    isUpgrading = false
                    return
                }
                try await subscriptionManager.purchase(product)
                isUpgrading = false
                showSuccessAlert = true
            } catch {
                isUpgrading = false
                print("Purchase failed: \(error)")
            }
        }
        #endif
    }
}

// MARK: - Subscription Tier Card

struct SubscriptionTierCard: View {
    let tier: SubscriptionTier
    let isCurrentTier: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if tier == .paid {
                        Text("$9.99/month")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if tier == .paid {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.body)
                        Text(feature)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            if isCurrentTier {
                HStack {
                    Spacer()
                    Text("Current Plan")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if tier == .paid {
                Button(action: action) {
                    HStack {
                        Spacer()
                        Text("Upgrade Now")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentTier ? Color.green : Color.gray.opacity(0.3), lineWidth: isCurrentTier ? 2 : 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Feature Bullet

struct FeatureBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - BLE Logs View

struct BLELogsView: View {
    @Environment(\.dismiss) private var dismiss
    let logs: [BLELogMessage]
    @State private var searchText = ""
    
    var filteredLogs: [BLELogMessage] {
        if searchText.isEmpty {
            return logs
        }
        return logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Logs")
                            .font(.headline)
                        
                        Text(searchText.isEmpty ? "No logs available" : "No logs matching '\(searchText)'")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(Array(filteredLogs.enumerated().reversed()), id: \.offset) { index, log in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Entry #\(filteredLogs.count - index)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(log.timestamp, style: .time)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("BLE Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search logs...")
        }
    }
}
