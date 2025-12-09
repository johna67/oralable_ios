//
//  PatientHealthDataView.swift
//  OralableForProfessionals
//
//  Created: HealthKit Integration - Step 8
//  Purpose: Display participant's HealthKit data correlated with oral wellness metrics
//

import SwiftUI
import Charts

struct PatientHealthDataView: View {
    @EnvironmentObject var designSystem: DesignSystem
    let patientData: HealthDataRecord

    var body: some View {
        ScrollView {
            VStack(spacing: designSystem.spacing.lg) {
                // Header
                headerSection

                // Health Metrics Overview
                if let healthKit = patientData.healthKitData {
                    healthMetricsOverviewSection(healthKit: healthKit)

                    // Heart Rate Chart
                    if !healthKit.heartRateReadings.isEmpty {
                        heartRateChartSection(readings: healthKit.heartRateReadings)
                    }

                    // SpO2 Chart
                    if !healthKit.spo2Readings.isEmpty {
                        spo2ChartSection(readings: healthKit.spo2Readings)
                    }

                    // Correlation Insights
                    correlationInsightsSection(healthKit: healthKit)
                } else {
                    noHealthKitDataSection
                }
            }
            .padding(designSystem.spacing.md)
        }
        .navigationTitle("Health Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Participant Health Data")
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(designSystem.colors.textSecondary)
                Text(patientData.recordingDate.formatted(date: .long, time: .shortened))
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(designSystem.colors.textSecondary)
                Text("Duration: \(formatDuration(patientData.sessionDuration))")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - Health Metrics Overview

    private func healthMetricsOverviewSection(healthKit: HealthKitDataForSharing) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Health Metrics")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            HStack(spacing: designSystem.spacing.md) {
                // Average Heart Rate
                MetricCard(
                    icon: "heart.fill",
                    title: "Avg Heart Rate",
                    value: healthKit.averageHeartRate.map { String(format: "%.0f bpm", $0) } ?? "-- bpm",
                    iconColor: .red,
                    subtitle: "\(healthKit.heartRateReadings.count) readings"
                )

                // Average SpO2
                MetricCard(
                    icon: "lungs.fill",
                    title: "Avg Blood Oxygen",
                    value: healthKit.averageSpO2.map { String(format: "%.1f%%", $0) } ?? "-- %",
                    iconColor: .blue,
                    subtitle: "\(healthKit.spo2Readings.count) readings"
                )
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - Heart Rate Chart

    private func heartRateChartSection(readings: [HealthDataReading]) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Heart Rate Trend")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            Chart(readings) { reading in
                LineMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("BPM", reading.value)
                )
                .foregroundStyle(Color.red.gradient)
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute(), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - SpO2 Chart

    private func spo2ChartSection(readings: [HealthDataReading]) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Blood Oxygen Trend")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            Chart(readings) { reading in
                LineMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("SpO2", reading.value)
                )
                .foregroundStyle(Color.blue.gradient)
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .chartYScale(domain: 90...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute(), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - Correlation Insights

    private func correlationInsightsSection(healthKit: HealthKitDataForSharing) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("Clinical Insights")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                InsightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Heart rate variability may indicate stress levels correlating with muscle activity episodes"
                )

                if let avgSpO2 = healthKit.averageSpO2, avgSpO2 < 95 {
                    InsightRow(
                        icon: "exclamationmark.triangle.fill",
                        text: "Lower oxygen saturation detected - may indicate sleep apnea, a known risk factor for elevated muscle activity",
                        iconColor: .orange
                    )
                }

                InsightRow(
                    icon: "brain.head.profile",
                    text: "Correlation between sleep quality and muscle activity intensity can help tailor wellness recommendations"
                )
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - No HealthKit Data

    private var noHealthKitDataSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(designSystem.colors.textTertiary)

            Text("No HealthKit Data Available")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            Text("This participant has not authorized HealthKit data sharing")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(designSystem.spacing.xl)
        .frame(maxWidth: .infinity)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    let subtitle: String?

    init(icon: String, title: String, value: String, iconColor: Color, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.iconColor = iconColor
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 20))

                Text(title)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }

            Text(value)
                .font(designSystem.typography.h2)
                .foregroundColor(designSystem.colors.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(designSystem.typography.caption2)
                    .foregroundColor(designSystem.colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundTertiary)
        .cornerRadius(designSystem.cornerRadius.medium)
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    let icon: String
    let text: String
    var iconColor: Color = .blue

    var body: some View {
        HStack(alignment: .top, spacing: designSystem.spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 16))
                .frame(width: 20)

            Text(text)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Preview

struct PatientHealthDataView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PatientHealthDataView(
                patientData: HealthDataRecord(
                    recordID: "test-123",
                    recordingDate: Date(),
                    dataType: "wellness_session",
                    measurements: Data(),
                    sessionDuration: 28800,  // 8 hours
                    healthKitData: HealthKitDataForSharing(
                        heartRateReadings: [
                            HealthDataReading(type: .heartRate, value: 72, timestamp: Date()),
                            HealthDataReading(type: .heartRate, value: 68, timestamp: Date().addingTimeInterval(-3600)),
                            HealthDataReading(type: .heartRate, value: 75, timestamp: Date().addingTimeInterval(-7200))
                        ],
                        spo2Readings: [
                            HealthDataReading(type: .bloodOxygen, value: 98, timestamp: Date()),
                            HealthDataReading(type: .bloodOxygen, value: 97, timestamp: Date().addingTimeInterval(-3600)),
                            HealthDataReading(type: .bloodOxygen, value: 96, timestamp: Date().addingTimeInterval(-7200))
                        ],
                        sleepData: nil
                    )
                )
            )
            .environmentObject(DesignSystem())
        }
    }
}
