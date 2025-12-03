//
//  AccelerometerDisplayView.swift
//  OralableApp
//
//  Created: December 3, 2025
//  Displays accelerometer data in g units with visual indicators
//

import SwiftUI

// MARK: - Accelerometer Display View

/// Displays accelerometer data in g units with visual indicators
struct AccelerometerDisplayView: View {
    let xRaw: Int16
    let yRaw: Int16
    let zRaw: Int16

    private var xG: Double { AccelerometerConversion.toG(xRaw) }
    private var yG: Double { AccelerometerConversion.toG(yRaw) }
    private var zG: Double { AccelerometerConversion.toG(zRaw) }
    private var magnitude: Double { AccelerometerConversion.magnitude(xG: xG, yG: yG, zG: zG) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accelerometer")
                .font(.headline)

            // Individual axes
            HStack(spacing: 20) {
                AccelerometerAxisView(label: "X", value: xG, color: .red)
                AccelerometerAxisView(label: "Y", value: yG, color: .green)
                AccelerometerAxisView(label: "Z", value: zG, color: .blue)
            }

            // Magnitude
            HStack {
                Text("Magnitude:")
                    .foregroundColor(.secondary)
                Text(AccelerometerConversion.formatG(magnitude))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                // Rest indicator
                if AccelerometerConversion.isAtRest(x: xRaw, y: yRaw, z: zRaw) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Axis View

struct AccelerometerAxisView: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(String(format: "%.2f", value))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)

            Text("g")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Compact Accelerometer View

/// A more compact version for use in cards or lists
struct AccelerometerCompactView: View {
    let xRaw: Int16
    let yRaw: Int16
    let zRaw: Int16

    private var xG: Double { AccelerometerConversion.toG(xRaw) }
    private var yG: Double { AccelerometerConversion.toG(yRaw) }
    private var zG: Double { AccelerometerConversion.toG(zRaw) }
    private var magnitude: Double { AccelerometerConversion.magnitude(xG: xG, yG: yG, zG: zG) }
    private var isAtRest: Bool { AccelerometerConversion.isAtRest(x: xRaw, y: yRaw, z: zRaw) }

    var body: some View {
        HStack(spacing: 16) {
            // Magnitude with status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(isAtRest ? Color.blue : Color.green)
                    .frame(width: 8, height: 8)

                Text(AccelerometerConversion.formatG(magnitude))
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()

            // XYZ values
            HStack(spacing: 8) {
                Text("X:\(String(format: "%.1f", xG))")
                    .foregroundColor(.red)
                Text("Y:\(String(format: "%.1f", yG))")
                    .foregroundColor(.green)
                Text("Z:\(String(format: "%.1f", zG))")
                    .foregroundColor(.blue)
            }
            .font(.system(.caption, design: .monospaced))
        }
    }
}

// MARK: - Accelerometer Card View

/// Card-style view for dashboard integration
struct AccelerometerCardView: View {
    let xRaw: Int16
    let yRaw: Int16
    let zRaw: Int16
    let showChevron: Bool

    private var magnitude: Double {
        AccelerometerConversion.magnitude(x: xRaw, y: yRaw, z: zRaw)
    }
    private var isAtRest: Bool {
        AccelerometerConversion.isAtRest(x: xRaw, y: yRaw, z: zRaw)
    }

    init(xRaw: Int16, yRaw: Int16, zRaw: Int16, showChevron: Bool = false) {
        self.xRaw = xRaw
        self.yRaw = yRaw
        self.zRaw = zRaw
        self.showChevron = showChevron
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "move.3d")
                    .font(.system(size: 20))
                    .foregroundColor(isAtRest ? .blue : .green)

                Text("Accelerometer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }

            // Value
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", magnitude))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Text("g")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)

                Spacer()

                // Status text
                Text(isAtRest ? "At Rest" : "Moving")
                    .font(.system(size: 14))
                    .foregroundColor(isAtRest ? .blue : .green)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview

#if DEBUG
struct AccelerometerDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Device flat face up (Z = ~1g)
            AccelerometerDisplayView(
                xRaw: 0,
                yRaw: 0,
                zRaw: 4098  // ~1g at 0.244 mg/digit
            )

            // Device tilted
            AccelerometerDisplayView(
                xRaw: 2900,  // ~0.7g
                yRaw: 0,
                zRaw: 2900   // ~0.7g
            )

            // Compact view
            AccelerometerCompactView(
                xRaw: 0,
                yRaw: 0,
                zRaw: 4098
            )
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)

            // Card view
            AccelerometerCardView(
                xRaw: 0,
                yRaw: 0,
                zRaw: 4098,
                showChevron: true
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
#endif
