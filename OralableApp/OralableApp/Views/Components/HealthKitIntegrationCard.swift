//
//  HealthKitIntegrationCard.swift
//  OralableApp
//
//  Created: HealthKit Integration - Step 5
//  Purpose: Display HealthKit data in Dashboard
//

import SwiftUI

struct HealthKitIntegrationCard: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var latestHeartRate: HealthDataReading?
    @State private var latestSpO2: HealthDataReading?
    @State private var isLoading = false
    @State private var showPermissionSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            // Header
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)

                Text("Apple Health")
                    .font(designSystem.typography.h3)
                    .foregroundColor(designSystem.colors.textPrimary)

                Spacer()

                if healthKitManager.isAuthorized {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
            }

            // Content based on authorization status
            if !healthKitManager.isAvailable {
                unavailableView
            } else if !healthKitManager.isAuthorized {
                notAuthorizedView
            } else if isLoading {
                loadingView
            } else {
                healthDataView
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
        .onAppear {
            if healthKitManager.isAuthorized {
                loadHealthData()
            }
        }
        .sheet(isPresented: $showPermissionSheet) {
            HealthKitPermissionView()
        }
    }

    // MARK: - Subviews

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("HealthKit Not Available")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)

            Text("Apple Health is not available on this device")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
        }
    }

    private var notAuthorizedView: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Connect to view health insights")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)

            Button(action: { showPermissionSheet = true }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Connect Apple Health")
                }
                .font(designSystem.typography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, designSystem.spacing.sm)
                .background(Color.red)
                .cornerRadius(designSystem.cornerRadius.medium)
            }
        }
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
        .padding(.vertical, designSystem.spacing.lg)
    }

    private var healthDataView: some View {
        VStack(spacing: designSystem.spacing.md) {
            // Health Metrics
            HStack(spacing: designSystem.spacing.md) {
                // Heart Rate
                HealthMetricItem(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: latestHeartRate?.formattedValue ?? "-- bpm",
                    iconColor: .red,
                    timestamp: latestHeartRate?.timestamp
                )

                Divider()
                    .frame(height: 40)

                // SpO2
                HealthMetricItem(
                    icon: "lungs.fill",
                    title: "Blood Oxygen",
                    value: latestSpO2?.formattedValue ?? "-- %",
                    iconColor: .blue,
                    timestamp: latestSpO2?.timestamp
                )
            }

            // Sync Status
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(designSystem.colors.textTertiary)

                Text("Auto-syncing with Apple Health")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)

                Spacer()

                Button(action: loadHealthData) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(designSystem.colors.primaryBlack)
                }
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Actions

    private func loadHealthData() {
        guard !isLoading else { return }

        isLoading = true

        Task {
            do {
                // Read heart rate from last 24 hours
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                let heartRates = try await healthKitManager.readHeartRateSamples(
                    from: yesterday,
                    to: Date()
                )
                if let latest = heartRates.first {
                    await MainActor.run {
                        latestHeartRate = latest
                    }
                }

                // Read SpO2 from last 24 hours
                let spo2Readings = try await healthKitManager.readBloodOxygenSamples(
                    from: yesterday,
                    to: Date()
                )
                if let latest = spo2Readings.first {
                    await MainActor.run {
                        latestSpO2 = latest
                    }
                }

                await MainActor.run {
                    isLoading = false
                }
            } catch {
                Logger.shared.error("[loading health data: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Health Metric Item

struct HealthMetricItem: View {
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    let timestamp: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            Text(value)
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            if let timestamp = timestamp {
                Text(timeAgo(from: timestamp))
                    .font(designSystem.typography.caption2)
                    .foregroundColor(designSystem.colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Preview

struct HealthKitIntegrationCard_Previews: PreviewProvider {
    static var previews: some View {
        let designSystem = DesignSystem()
        VStack(spacing: 16) {
            // Authorized state
            HealthKitIntegrationCard()
                .environmentObject(designSystem)
                .environmentObject({
                    let manager = HealthKitManager()
                    return manager
                }())

            // Not authorized state
            HealthKitIntegrationCard()
                .environmentObject(designSystem)
                .environmentObject({
                    let manager = HealthKitManager()
                    return manager
                }())
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
