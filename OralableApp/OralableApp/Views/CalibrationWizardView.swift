//
//  CalibrationWizardView.swift
//  OralableApp
//
//  Multi-step calibration wizard for Oralable device sensors
//

import SwiftUI

struct CalibrationWizardView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) var dismiss
    @ObservedObject var bleManager: OralableBLE

    @State private var currentStep: CalibrationStep = .intro
    @State private var isCalibrating = false
    @State private var calibrationProgress: Double = 0.0
    @State private var calibrationComplete = false
    @State private var calibrationError: String? = nil

    // Calibration results
    @State private var ppgBaseline: Double = 0
    @State private var accelerometerBaseline: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @State private var temperatureBaseline: Double = 0

    enum CalibrationStep: Int, CaseIterable {
        case intro = 0
        case preparation = 1
        case ppgCalibration = 2
        case accelerometerCalibration = 3
        case temperatureCalibration = 4
        case completion = 5

        var title: String {
            switch self {
            case .intro: return "Sensor Calibration"
            case .preparation: return "Preparation"
            case .ppgCalibration: return "PPG Calibration"
            case .accelerometerCalibration: return "Accelerometer Calibration"
            case .temperatureCalibration: return "Temperature Calibration"
            case .completion: return "Calibration Complete"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                if currentStep != .intro && currentStep != .completion {
                    progressIndicator
                }

                ScrollView {
                    VStack(spacing: designSystem.spacing.xl) {
                        Spacer()
                            .frame(height: designSystem.spacing.lg)

                        // Step Content
                        stepContent

                        Spacer()
                            .frame(height: designSystem.spacing.xl)
                    }
                    .padding(designSystem.spacing.xl)
                }

                // Navigation Buttons
                navigationButtons
            }
            .background(designSystem.colors.backgroundPrimary)
            .navigationTitle(currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentStep == .intro || currentStep == .completion {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        let totalSteps = CalibrationStep.allCases.count - 2 // Exclude intro and completion
        let currentProgress = Double(currentStep.rawValue - 1) / Double(totalSteps)

        return VStack(spacing: designSystem.spacing.xs) {
            ProgressView(value: currentProgress, total: 1.0)
                .padding(.horizontal, designSystem.spacing.xl)
                .padding(.top, designSystem.spacing.md)

            Text("Step \(currentStep.rawValue) of \(totalSteps)")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textSecondary)
                .padding(.bottom, designSystem.spacing.md)
        }
        .background(designSystem.colors.backgroundSecondary)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .intro:
            introView
        case .preparation:
            preparationView
        case .ppgCalibration:
            ppgCalibrationView
        case .accelerometerCalibration:
            accelerometerCalibrationView
        case .temperatureCalibration:
            temperatureCalibrationView
        case .completion:
            completionView
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack(spacing: designSystem.spacing.xl) {
            Image(systemName: "tuningfork")
                .font(.system(size: 80))
                .foregroundColor(designSystem.colors.primaryBlack)

            VStack(spacing: designSystem.spacing.md) {
                Text("Sensor Calibration")
                    .font(designSystem.typography.h1)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text("This wizard will guide you through calibrating your device's sensors for optimal accuracy.")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                calibrationInfoRow(icon: "waveform.path.ecg", text: "PPG sensor calibration")
                calibrationInfoRow(icon: "move.3d", text: "Accelerometer calibration")
                calibrationInfoRow(icon: "thermometer", text: "Temperature calibration")
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)

            Text("This process will take about 3 minutes.")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
        }
    }

    // MARK: - Preparation View

    private var preparationView: some View {
        VStack(spacing: designSystem.spacing.xl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: designSystem.spacing.md) {
                Text("Before You Begin")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text("Please ensure the following conditions are met:")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                preparationCheckRow(icon: "battery.100", text: "Device battery is above 50%", isOk: bleManager.batteryLevel > 50)
                preparationCheckRow(icon: "wifi", text: "Strong BLE connection", isOk: bleManager.rssi > -70)
                preparationCheckRow(icon: "figure.stand", text: "You are in a quiet position", isOk: true)
                preparationCheckRow(icon: "thermometer", text: "Room temperature is stable", isOk: true)
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
        }
    }

    // MARK: - PPG Calibration View

    private var ppgCalibrationView: some View {
        VStack(spacing: designSystem.spacing.xl) {
            if isCalibrating {
                ProgressView()
                    .scaleEffect(2)
                    .padding(designSystem.spacing.xl)
            } else {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
            }

            VStack(spacing: designSystem.spacing.md) {
                Text("PPG Sensor Calibration")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)

                if isCalibrating {
                    Text("Calibrating... Please remain still")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)

                    ProgressView(value: calibrationProgress, total: 1.0)
                        .padding(.horizontal, designSystem.spacing.xl)

                    Text("\(Int(calibrationProgress * 100))%")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                } else {
                    Text("Place the device in the correct position and tap 'Start Calibration' when ready.")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Real-time PPG display
            if !isCalibrating {
                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    Text("Current PPG Reading")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack {
                        Text("Red:")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text("\(Int(bleManager.ppgRedValue))")
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    .font(designSystem.typography.body)

                    HStack {
                        Text("IR:")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text("\(Int(bleManager.ppgIRValue))")
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    .font(designSystem.typography.body)

                    HStack {
                        Text("Green:")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text("\(Int(bleManager.ppgGreenValue))")
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    .font(designSystem.typography.body)
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.md)
            }
        }
    }

    // MARK: - Accelerometer Calibration View

    private var accelerometerCalibrationView: some View {
        VStack(spacing: designSystem.spacing.xl) {
            if isCalibrating {
                ProgressView()
                    .scaleEffect(2)
                    .padding(designSystem.spacing.xl)
            } else {
                Image(systemName: "move.3d")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
            }

            VStack(spacing: designSystem.spacing.md) {
                Text("Accelerometer Calibration")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)

                if isCalibrating {
                    Text("Calibrating... Keep device still")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)

                    ProgressView(value: calibrationProgress, total: 1.0)
                        .padding(.horizontal, designSystem.spacing.xl)

                    Text("\(Int(calibrationProgress * 100))%")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                } else {
                    Text("Place the device on a flat, stable surface and tap 'Start Calibration'.")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Real-time accelerometer display
            if !isCalibrating {
                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    Text("Current Accelerometer Reading")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack {
                        Text("X:")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(String(format: "%.3f g", bleManager.accelX))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    .font(designSystem.typography.body)

                    HStack {
                        Text("Y:")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(String(format: "%.3f g", bleManager.accelY))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    .font(designSystem.typography.body)

                    HStack {
                        Text("Z:")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(String(format: "%.3f g", bleManager.accelZ))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    .font(designSystem.typography.body)
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.md)
            }
        }
    }

    // MARK: - Temperature Calibration View

    private var temperatureCalibrationView: some View {
        VStack(spacing: designSystem.spacing.xl) {
            if isCalibrating {
                ProgressView()
                    .scaleEffect(2)
                    .padding(designSystem.spacing.xl)
            } else {
                Image(systemName: "thermometer")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
            }

            VStack(spacing: designSystem.spacing.md) {
                Text("Temperature Calibration")
                    .font(designSystem.typography.h2)
                    .foregroundColor(designSystem.colors.textPrimary)

                if isCalibrating {
                    Text("Calibrating... Measuring ambient temperature")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)

                    ProgressView(value: calibrationProgress, total: 1.0)
                        .padding(.horizontal, designSystem.spacing.xl)

                    Text("\(Int(calibrationProgress * 100))%")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textTertiary)
                } else {
                    Text("Remove the device from your body and let it stabilize for 30 seconds before calibrating.")
                        .font(designSystem.typography.body)
                        .foregroundColor(designSystem.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Real-time temperature display
            if !isCalibrating {
                VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                    Text("Current Temperature")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)

                    HStack {
                        Text("Reading:")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(String(format: "%.1f°C", bleManager.temperature))
                            .font(designSystem.typography.h3)
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.backgroundSecondary)
                .cornerRadius(designSystem.cornerRadius.md)
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: designSystem.spacing.xl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: designSystem.spacing.md) {
                Text("Calibration Complete")
                    .font(designSystem.typography.h1)
                    .foregroundColor(designSystem.colors.textPrimary)

                Text("Your device sensors have been successfully calibrated!")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: designSystem.spacing.md) {
                calibrationResultRow(icon: "waveform.path.ecg", label: "PPG Baseline", value: "\(Int(ppgBaseline))")
                calibrationResultRow(icon: "move.3d", label: "Accelerometer", value: "Calibrated")
                calibrationResultRow(icon: "thermometer", label: "Temperature Baseline", value: String(format: "%.1f°C", temperatureBaseline))
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)

            Text("Calibration settings have been saved to your device.")
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helper Views

    private func calibrationInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: designSystem.spacing.md) {
            Image(systemName: icon)
                .foregroundColor(designSystem.colors.primaryBlack)
                .frame(width: 24)
            Text(text)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)
        }
    }

    private func preparationCheckRow(icon: String, text: String, isOk: Bool) -> some View {
        HStack(spacing: designSystem.spacing.md) {
            Image(systemName: icon)
                .foregroundColor(designSystem.colors.textSecondary)
                .frame(width: 24)
            Text(text)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)
            Spacer()
            Image(systemName: isOk ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isOk ? .green : .red)
        }
    }

    private func calibrationResultRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: designSystem.spacing.md) {
            Image(systemName: icon)
                .foregroundColor(designSystem.colors.textSecondary)
                .frame(width: 24)
            Text(label)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
            Spacer()
            Text(value)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)
        }
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: designSystem.spacing.md) {
            // Back Button
            if currentStep.rawValue > 0 && currentStep != .completion {
                Button(action: { previousStep() }) {
                    Text("Back")
                        .font(designSystem.typography.button)
                        .foregroundColor(designSystem.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(designSystem.spacing.md)
                        .background(designSystem.colors.backgroundSecondary)
                        .cornerRadius(designSystem.cornerRadius.md)
                }
                .disabled(isCalibrating)
            }

            // Next/Calibrate Button
            if currentStep != .completion {
                Button(action: { nextStep() }) {
                    Text(buttonText)
                        .font(designSystem.typography.buttonLarge)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(designSystem.spacing.md)
                        .background(isCalibrating ? Color.gray : Color.blue)
                        .cornerRadius(designSystem.cornerRadius.md)
                }
                .disabled(isCalibrating || !canProceed)
            }
        }
        .padding(designSystem.spacing.lg)
        .background(designSystem.colors.backgroundSecondary)
    }

    private var buttonText: String {
        if isCalibrating {
            return "Calibrating..."
        }

        switch currentStep {
        case .intro:
            return "Start"
        case .preparation:
            return "Continue"
        case .ppgCalibration, .accelerometerCalibration, .temperatureCalibration:
            return "Start Calibration"
        case .completion:
            return "Done"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case .preparation:
            return bleManager.batteryLevel > 50 && bleManager.rssi > -70
        default:
            return true
        }
    }

    // MARK: - Navigation Logic

    private func nextStep() {
        switch currentStep {
        case .intro:
            currentStep = .preparation
        case .preparation:
            currentStep = .ppgCalibration
        case .ppgCalibration:
            if !isCalibrating {
                startPPGCalibration()
            }
        case .accelerometerCalibration:
            if !isCalibrating {
                startAccelerometerCalibration()
            }
        case .temperatureCalibration:
            if !isCalibrating {
                startTemperatureCalibration()
            }
        case .completion:
            dismiss()
        }
    }

    private func previousStep() {
        guard currentStep.rawValue > 0, !isCalibrating else { return }
        currentStep = CalibrationStep(rawValue: currentStep.rawValue - 1) ?? .intro
    }

    // MARK: - Calibration Logic

    private func startPPGCalibration() {
        isCalibrating = true
        calibrationProgress = 0.0

        // Simulate calibration process
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            calibrationProgress += 0.02

            if calibrationProgress >= 1.0 {
                timer.invalidate()
                completePPGCalibration()
            }
        }
    }

    private func completePPGCalibration() {
        // Save baseline value
        ppgBaseline = bleManager.ppgIRValue

        // In production, send calibration command to device
        // bleManager.sendCalibrationCommand(.ppg, baseline: ppgBaseline)

        isCalibrating = false
        calibrationProgress = 0.0
        currentStep = .accelerometerCalibration
    }

    private func startAccelerometerCalibration() {
        isCalibrating = true
        calibrationProgress = 0.0

        // Simulate calibration process
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            calibrationProgress += 0.02

            if calibrationProgress >= 1.0 {
                timer.invalidate()
                completeAccelerometerCalibration()
            }
        }
    }

    private func completeAccelerometerCalibration() {
        // Save baseline values
        accelerometerBaseline = (
            x: bleManager.accelX,
            y: bleManager.accelY,
            z: bleManager.accelZ
        )

        // In production, send calibration command to device
        // bleManager.sendCalibrationCommand(.accelerometer, baseline: accelerometerBaseline)

        isCalibrating = false
        calibrationProgress = 0.0
        currentStep = .temperatureCalibration
    }

    private func startTemperatureCalibration() {
        isCalibrating = true
        calibrationProgress = 0.0

        // Simulate calibration process
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            calibrationProgress += 0.02

            if calibrationProgress >= 1.0 {
                timer.invalidate()
                completeTemperatureCalibration()
            }
        }
    }

    private func completeTemperatureCalibration() {
        // Save baseline value
        temperatureBaseline = bleManager.temperature

        // In production, send calibration command to device
        // bleManager.sendCalibrationCommand(.temperature, baseline: temperatureBaseline)

        isCalibrating = false
        calibrationProgress = 0.0
        calibrationComplete = true
        currentStep = .completion
    }
}

// MARK: - Preview

struct CalibrationWizardView_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationWizardView(bleManager: OralableBLE.shared)
            .environmentObject(DesignSystem.shared)
    }
}
