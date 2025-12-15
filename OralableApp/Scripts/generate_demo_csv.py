#!/usr/bin/env python3
"""
Generate synthetic Oralable demo data CSV
Creates realistic muscle activity patterns for Demo Mode
"""

import csv
import math
import random
from datetime import datetime, timedelta

def generate_demo_csv(output_path: str, duration_seconds: int = 120):
    """
    Generate a synthetic CSV file with realistic PPG/accelerometer data.

    Args:
        output_path: Path to save the CSV file
        duration_seconds: Duration of demo data (default 120 seconds = 2 minutes)
    """

    # Sample rate: 20Hz (matches real device)
    sample_rate = 20
    total_samples = duration_seconds * sample_rate

    # Start time (will be replaced with relative time during playback)
    start_time = datetime.now()

    rows = []

    for i in range(total_samples):
        # Timestamp
        timestamp = start_time + timedelta(seconds=i / sample_rate)
        timestamp_str = timestamp.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

        # Time in seconds for pattern generation
        t = i / sample_rate

        # === PPG IR Signal ===
        # Baseline with slow drift
        baseline = 50000 + 2000 * math.sin(t / 30)  # Slow baseline drift

        # Cardiac pulse component (~70 BPM)
        heart_rate = 70 + random.uniform(-2, 2)
        cardiac = 1500 * math.sin(2 * math.pi * (heart_rate / 60) * t)

        # Breathing component (~15 breaths/min)
        breathing = 800 * math.sin(2 * math.pi * (15 / 60) * t)

        # Muscle activity / clenching events
        # Create 4-5 clench events per minute, varying intensity
        clench_amplitude = 0
        for clench_start in range(0, duration_seconds, 15):  # Every ~15 seconds
            clench_duration = random.uniform(2, 4)  # 2-4 second clench
            if clench_start <= t < clench_start + clench_duration:
                # Ramp up, hold, ramp down
                progress = (t - clench_start) / clench_duration
                if progress < 0.2:
                    clench_amplitude = (progress / 0.2) * random.uniform(10000, 20000)
                elif progress > 0.8:
                    clench_amplitude = ((1 - progress) / 0.2) * random.uniform(10000, 20000)
                else:
                    clench_amplitude = random.uniform(10000, 20000)

        # Random noise
        noise = random.gauss(0, 300)

        # Combined PPG IR value
        ppg_ir = int(baseline + cardiac + breathing + clench_amplitude + noise)
        ppg_ir = max(0, min(262143, ppg_ir))  # Clamp to valid range

        # PPG Red and Green (secondary channels, correlated with IR)
        ppg_red = int(ppg_ir * 0.7 + random.gauss(0, 200))
        ppg_green = int(ppg_ir * 0.5 + random.gauss(0, 150))

        # === Accelerometer ===
        # Mostly stationary with occasional small movements
        accel_base_x = random.gauss(0, 0.01)
        accel_base_y = random.gauss(0, 0.01)
        accel_base_z = 1.0 + random.gauss(0, 0.01)  # Gravity

        # Occasional movement artifacts (correlate with clench events)
        if clench_amplitude > 5000:
            accel_base_x += random.gauss(0, 0.05)
            accel_base_y += random.gauss(0, 0.05)

        # Convert to raw values (LIS2DTW12: 16384 LSB/g at ±2g)
        accel_x = int(accel_base_x * 16384)
        accel_y = int(accel_base_y * 16384)
        accel_z = int(accel_base_z * 16384)

        # === Temperature ===
        # Body temperature with slight variation
        temperature = 36.5 + 0.3 * math.sin(t / 60) + random.gauss(0, 0.05)

        # === Heart Rate (derived) ===
        heart_rate_display = int(heart_rate + random.gauss(0, 1))

        # === SpO2 (derived) ===
        spo2 = 98 + random.gauss(0, 0.5)
        spo2 = max(95, min(100, spo2))

        # === Battery ===
        battery = 85  # Static for demo

        rows.append({
            'timestamp': timestamp_str,
            'ppg_ir': ppg_ir,
            'ppg_red': ppg_red,
            'ppg_green': ppg_green,
            'accel_x': accel_x,
            'accel_y': accel_y,
            'accel_z': accel_z,
            'temperature': f"{temperature:.2f}",
            'heart_rate': heart_rate_display,
            'spo2': f"{spo2:.1f}",
            'battery': battery,
            'device_id': 'DEMO-ORALABLE-001'
        })

    # Write CSV
    fieldnames = ['timestamp', 'ppg_ir', 'ppg_red', 'ppg_green',
                  'accel_x', 'accel_y', 'accel_z', 'temperature',
                  'heart_rate', 'spo2', 'battery', 'device_id']

    with open(output_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Generated {len(rows)} samples ({duration_seconds} seconds) to {output_path}")


if __name__ == "__main__":
    generate_demo_csv("oralable_demo_data.csv", duration_seconds=120)
