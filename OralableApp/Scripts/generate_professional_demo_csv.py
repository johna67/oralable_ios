#!/usr/bin/env python3
"""
Generate demo participant data for Oralable for Professionals
Creates multiple sessions to show realistic participant history
"""

import csv
import math
import random
from datetime import datetime, timedelta

def generate_session(session_id: int, session_date: datetime, duration_minutes: int):
    """Generate a single session's data."""

    rows = []
    sample_rate = 20
    total_samples = duration_minutes * 60 * sample_rate

    for i in range(total_samples):
        timestamp = session_date + timedelta(seconds=i / sample_rate)
        timestamp_str = timestamp.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

        t = i / sample_rate

        # PPG with session-specific patterns
        baseline = 48000 + 4000 * math.sin(t / 45)
        cardiac = 1200 * math.sin(2 * math.pi * (72 / 60) * t)
        breathing = 600 * math.sin(2 * math.pi * (14 / 60) * t)

        # Muscle activity - varies by session
        clench_frequency = 12 + session_id * 3  # Different patterns per session
        clench_amplitude = 0
        for clench_start in range(0, duration_minutes * 60, clench_frequency):
            clench_duration = random.uniform(1.5, 3.5)
            if clench_start <= t < clench_start + clench_duration:
                progress = (t - clench_start) / clench_duration
                if progress < 0.15:
                    clench_amplitude = (progress / 0.15) * random.uniform(8000, 18000)
                elif progress > 0.85:
                    clench_amplitude = ((1 - progress) / 0.15) * random.uniform(8000, 18000)
                else:
                    clench_amplitude = random.uniform(8000, 18000)

        noise = random.gauss(0, 250)
        ppg_ir = int(baseline + cardiac + breathing + clench_amplitude + noise)

        # Accelerometer
        accel_x = int(random.gauss(0, 150))
        accel_y = int(random.gauss(0, 150))
        accel_z = int(16384 + random.gauss(0, 150))

        # Temperature
        temperature = 36.4 + 0.2 * math.sin(t / 120) + random.gauss(0, 0.03)

        rows.append({
            'timestamp': timestamp_str,
            'ppg_ir': ppg_ir,
            'ppg_red': int(ppg_ir * 0.7),
            'ppg_green': int(ppg_ir * 0.5),
            'accel_x': accel_x,
            'accel_y': accel_y,
            'accel_z': accel_z,
            'temperature': f"{temperature:.2f}",
            'heart_rate': 72 + random.randint(-3, 3),
            'spo2': f"{98.0 + random.gauss(0, 0.4):.1f}",
            'battery': 90 - session_id * 5,
            'device_id': 'ORALABLE-DEMO-DEVICE'
        })

    return rows


def generate_professional_demo():
    """Generate multiple sessions for a demo participant."""

    # Create 3 sessions over the past week
    sessions = [
        {"id": 1, "date": datetime.now() - timedelta(days=5), "duration": 8},   # 8 min session
        {"id": 2, "date": datetime.now() - timedelta(days=3), "duration": 10},  # 10 min session
        {"id": 3, "date": datetime.now() - timedelta(days=1), "duration": 12},  # 12 min session
    ]

    fieldnames = ['timestamp', 'ppg_ir', 'ppg_red', 'ppg_green',
                  'accel_x', 'accel_y', 'accel_z', 'temperature',
                  'heart_rate', 'spo2', 'battery', 'device_id']

    for session in sessions:
        rows = generate_session(session["id"], session["date"], session["duration"])

        # Filename format: participant_session_date
        filename = f"demo_participant_session_{session['id']}.csv"

        with open(filename, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

        print(f"Generated {filename}: {len(rows)} samples ({session['duration']} minutes)")

    # Also create a combined file for easy import
    all_rows = []
    for session in sessions:
        rows = generate_session(session["id"], session["date"], session["duration"])
        all_rows.extend(rows)

    with open("demo_participant_all_sessions.csv", 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"\nGenerated combined file: demo_participant_all_sessions.csv ({len(all_rows)} total samples)")


if __name__ == "__main__":
    generate_professional_demo()
