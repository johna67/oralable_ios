//
//  CalibrationView.swift
//  OralableApp
//
//  Sensor calibration interface
//

import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    @State private var calibrationState: CalibrationState = .notStarted
    @State private var progress: Double = 0.0
    @State private var calibrationResult: String = ""
    @State private var showingResults = false

    enum CalibrationState {
        case notStarted
        case preparing
        case inProgress
        case completed
        case failed
    }

    var body: some View {
        VStack(spacing: designSystem.spacing.xl) {
            Spacer()

            // Status Icon
            statusIcon

            // Title
            Text(titleText)
                .font(designSystem.typography.title)
                .foregroundColor(designSystem.colors.textPrimary)

            // Description
            Text(descriptionText)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, designSystem.spacing.xl)

            // Progress indicator
            if calibrationState == .inProgress {
                VStack(spacing: designSystem.spacing.md) {
                    ProgressView(value: progress)
                        .tint(designSystem.colors.accentBlue)
                        .frame(width: 250)

                    Text("\(Int(progress * 100))% Complete")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }

            Spacer()

            // Action Buttons
            VStack(spacing: designSystem.spacing.md) {
                if calibrationState == .notStarted {
                    Button(action: startCalibration) {
                        Text("Start Calibration")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.primaryWhite)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(designSystem.colors.primaryBlack)
                            .cornerRadius(designSystem.cornerRadius.md)
                    }
                } else if calibrationState == .completed {
                    Button(action: {
                        showingResults = true
                    }) {
                        Text("View Results")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.primaryWhite)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(designSystem.colors.accentGreen)
                            .cornerRadius(designSystem.cornerRadius.md)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(designSystem.colors.backgroundSecondary)
                            .cornerRadius(designSystem.cornerRadius.md)
                    }
                } else if calibrationState == .failed {
                    Button(action: startCalibration) {
                        Text("Retry Calibration")
                            .font(designSystem.typography.headline)
                            .foregroundColor(designSystem.colors.primaryWhite)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(designSystem.colors.accentOrange)
                            .cornerRadius(designSystem.cornerRadius.md)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(designSystem.colors.backgroundSecondary)
                            .cornerRadius(designSystem.cornerRadius.md)
                    }
                }
            }
            .padding(.horizontal, designSystem.spacing.xl)
            .padding(.bottom, designSystem.spacing.xl)
        }
        .navigationTitle("Calibration")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingResults) {
            CalibrationResultsView(result: calibrationResult)
        }
    }

    // MARK: - Computed Properties

    private var statusIcon: some View {
        Group {
            switch calibrationState {
            case .notStarted:
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 80))
                    .foregroundColor(designSystem.colors.accentBlue)
            case .preparing:
                ProgressView()
                    .scaleEffect(2.0)
            case .inProgress:
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 80))
                    .foregroundColor(designSystem.colors.accentBlue)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(designSystem.colors.accentGreen)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(designSystem.colors.accentRed)
            }
        }
    }

    private var titleText: String {
        switch calibrationState {
        case .notStarted:
            return "Ready to Calibrate"
        case .preparing:
            return "Preparing..."
        case .inProgress:
            return "Calibrating Sensors"
        case .completed:
            return "Calibration Complete"
        case .failed:
            return "Calibration Failed"
        }
    }

    private var descriptionText: String {
        switch calibrationState {
        case .notStarted:
            return "Follow the instructions to calibrate your sensors for optimal accuracy. This process takes about 2 minutes."
        case .preparing:
            return "Preparing calibration sequence..."
        case .inProgress:
            return "Please remain still while the sensors are being calibrated. Do not move or talk."
        case .completed:
            return "Sensors have been successfully calibrated. You can now use your device with improved accuracy."
        case .failed:
            return "Calibration could not be completed. Please ensure the device is properly connected and try again."
        }
    }

    // MARK: - Actions

    private func startCalibration() {
        calibrationState = .preparing
        progress = 0.0

        // Simulate calibration process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            calibrationState = .inProgress

            // Simulate progress
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                progress += 0.05

                if progress >= 1.0 {
                    timer.invalidate()
                    completeCalibration()
                }
            }
        }
    }

    private func completeCalibration() {
        // Randomly succeed or fail for demo
        let success = Bool.random()

        if success {
            calibrationState = .completed
            calibrationResult = "Calibration successful. All sensors within optimal range."
        } else {
            calibrationState = .failed
            calibrationResult = "Calibration failed. Please try again."
        }
    }
}

// MARK: - Calibration Results View

struct CalibrationResultsView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    let result: String

    var body: some View {
        NavigationView {
            VStack(spacing: designSystem.spacing.lg) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(designSystem.colors.accentGreen)
                    .padding(.top, designSystem.spacing.xl)

                Text("Calibration Results")
                    .font(designSystem.typography.title)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text(result)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, designSystem.spacing.xl)

                Spacer()

                // Mock results
                VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                    ResultRow(sensor: "PPG Red", status: "✓ Optimal", color: .green)
                    ResultRow(sensor: "PPG IR", status: "✓ Optimal", color: .green)
                    ResultRow(sensor: "PPG Green", status: "✓ Optimal", color: .green)
                    ResultRow(sensor: "Accelerometer", status: "✓ Optimal", color: .green)
                    ResultRow(sensor: "Temperature", status: "✓ Optimal", color: .green)
                }
                .padding()
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.md)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ResultRow: View {
    let sensor: String
    let status: String
    let color: Color

    var body: some View {
        HStack {
            Text(sensor)
                .font(.body)
            Spacer()
            Text(status)
                .font(.body)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

struct CalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CalibrationView()
                .environmentObject(DesignSystem.shared)
        }
    }
}
