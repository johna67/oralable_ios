# TGM Firmware Protocol - Complete Reference

## Overview
This document describes the BLE data format for the Oralable TGM (Tongue Muscle Gauge) device firmware.

Based on: https://github.com/johna67/tgm_firmware

## BLE Service

**Service UUID:** `3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E`

## Characteristics

### 1. PPG Data (3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Streams photoplethysmography data from MAXM86161 sensor  
**Sampling Rate:** 50 Hz (configurable)  
**Samples Per Frame:** 20 (CONFIG_PPG_SAMPLES_PER_FRAME)  
**Update Rate:** Every 0.4 seconds (20 samples ÷ 50 Hz)  
**Packet Size:** 244 bytes

**Packet Structure:**
```
Bytes 0-3:   Frame counter (uint32_t, little-endian)
Bytes 4-7:   Sample 1 - Red LED   (uint32_t, little-endian)
Bytes 8-11:  Sample 1 - IR LED    (uint32_t, little-endian)
Bytes 12-15: Sample 1 - Green LED (uint32_t, little-endian)
Bytes 16-19: Sample 2 - Red LED   (uint32_t, little-endian)
... continues for 20 samples total
```

**Code Structure (tgm_service.h):**
```c
typedef struct {
    uint32_t frame_counter;
    struct {
        uint32_t red;
        uint32_t ir;
        uint32_t green;
    } samples[CONFIG_PPG_SAMPLES_PER_FRAME];
} tgm_service_ppg_data_t;
```

**Expected Values (MAXM86161 with good contact):**
- Red: 80,000 - 300,000 (typical: ~150k)
- IR: 100,000 - 400,000 (typical: ~200k, usually highest)
- Green: 50,000 - 250,000 (typical: ~100k)

---

### 2. Accelerometer Data (3A0FF002-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Streams 3-axis accelerometer data  
**Sampling Rate:** 50 Hz  
**Samples Per Frame:** 25 (CONFIG_ACC_SAMPLES_PER_FRAME)  
**Update Rate:** Every 0.5 seconds (25 samples ÷ 50 Hz)  
**Packet Size:** 154 bytes

**Packet Structure:**
```
Bytes 0-3:  Frame counter (uint32_t, little-endian)
Bytes 4-5:  Sample 1 - X axis (int16_t, little-endian, in mg)
Bytes 6-7:  Sample 1 - Y axis (int16_t, little-endian, in mg)
Bytes 8-9:  Sample 1 - Z axis (int16_t, little-endian, in mg)
Bytes 10-11: Sample 2 - X axis (int16_t, little-endian, in mg)
... continues for 25 samples total
```

**Code Structure (tgm_service.h):**
```c
typedef struct {
    uint32_t frame_counter;
    struct {
        int16_t x;  // milligravity
        int16_t y;  // milligravity
        int16_t z;  // milligravity
    } samples[CONFIG_ACC_SAMPLES_PER_FRAME];
} tgm_service_acc_data_t;
```

**Units:** Milligravity (mg), where 1000 mg = 1 g  
**Conversion:** Divide by 1000.0 to get g-force

---

### 3. Temperature Data (3A0FF003-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** BLE module temperature monitoring  
**Update Interval:** 1 second (CONFIG_TEMPERATURE_MEASUREMENT_INTERVAL)  
**Packet Size:** 8 bytes

**Packet Structure:**
```
Bytes 0-3: Frame counter (uint32_t, little-endian)
Bytes 4-5: Temperature (int16_t, little-endian, in centidegrees Celsius)
Bytes 6-7: Unused/padding
```

**Units:** Centidegrees Celsius (1/100°C)  
**Conversion:** Divide by 100.0 to get °C  
**Example:** Value 2137 = 21.37°C

**Expected Range:** 0°C to 60°C (BLE module operating temperature)

---

### 4. Battery Voltage (3A0FF004-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Battery voltage monitoring  
**Update Interval:** 300 seconds / 5 minutes (CONFIG_BATTERY_MEASUREMENT_INTERVAL)  
**Packet Size:** 4 bytes

**Packet Structure:**
```
Bytes 0-3: Battery voltage (int32_t, little-endian, in millivolts)
```

**Units:** Millivolts (mV)  
**Conversion:** Divide by 1000.0 to get volts  
**Example:** Value 3850 = 3.85V

**Typical Li-ion Battery Voltages:**
- 4.2V = 100% (fully charged)
- 3.7V = ~50% (nominal voltage)
- 3.0V = 0% (cutoff voltage)

---

### 5. Device UUID (3A0FF005-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Unique device identifier  
**Size:** 8 bytes (uint64_t)

---

### 6. Firmware Version (3A0FF006-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Firmware version string  
**Format:** ASCII string (e.g., "1.2.3")

---

### 7. PPG Register Read (3A0FF007-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Read MAXM86161 registers  
**Format:** 2 bytes
- Byte 0: Register address
- Byte 1: Register value

---

### 8. PPG Register Write (3A0FF008-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Write MAXM86161 registers for tuning  
**Format:** Write 2 bytes
- Byte 0: Register address (hex)
- Byte 1: Register value (hex)

**Common Registers:**
- `0x24XX` - IR LED current (0x00-0xFF, ~0.4mA per step)
- `0x25XX` - Red LED current (0x00-0xFF, ~0.4mA per step)

**Example:** Write `0x2430` to set IR LED to ~31mA

---

### 9. Muscle Site (3A0FF102-98C4-46B2-94AF-1AEE0FD4C48E)

**Purpose:** Target muscle site configuration  
**Details:** TBD

---

## Frame Counters

All streaming characteristics include a frame counter (uint32_t) that:
- Starts at 0 on device boot
- Increments by 1 for each transmitted packet
- Wraps around at 2^32 (4,294,967,296)
- Helps detect missed packets

## Byte Order

All multi-byte values use **little-endian** format (LSB first), which is the native format for ARM Cortex-M processors.

## Configuration

Edit `prj.conf` in firmware to adjust:
```conf
CONFIG_PPG_SAMPLES_PER_FRAME=20
CONFIG_ACC_SAMPLES_PER_FRAME=25
CONFIG_BATTERY_MEASUREMENT_INTERVAL=300
CONFIG_TEMPERATURE_MEASUREMENT_INTERVAL=1
```

## Sensor Hardware

**PPG Sensor:** MAXM86161  
- Integrated pulse oximetry and heart-rate monitor  
- 3 LEDs: Red (660nm), IR (880nm), Green (537nm)  
- 19-bit ADC resolution  
- Configurable LED current: 0-100mA

**Accelerometer:** TBD  
- 3-axis measurement  
- ±2g typical range

## References

- Firmware: https://github.com/johna67/tgm_firmware
- MAXM86161 Datasheet: [Analog Devices/Maxim]
- nRF Connect SDK Documentation

Last updated: November 6, 2025
