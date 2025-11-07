# PPG Signal Parsing Debugging Guide

## Problem
The PPG signals from the three LEDs (IR, Red, and Green) are being incorrectly parsed and appear mixed up, with values appearing random and not settling on constant figures.

## Root Cause
The issue is likely due to **incorrect channel ordering** when parsing the BLE data packets from the device. The firmware sends the three PPG channels in a specific order, and if the app parses them in a different order, the values get assigned to the wrong channels.

## Solution Implemented

### 1. Configurable Channel Order
Added a new `PPGChannelOrder` enum that supports all 6 possible orderings:
- IR, Red, Green (most common for MAX30102-based devices)
- Red, IR, Green
- Green, Red, IR  
- Red, Green, IR
- IR, Green, Red
- Green, IR, Red

### 2. Runtime Channel Selection
Added a picker in Settings → PPG Configuration that lets you test different channel orders in real-time without rebuilding the app.

### 3. Enhanced Debugging
The parsing now logs:
- Raw hex bytes for the first 24 bytes of each packet
- The three raw values at positions 0, 1, and 2
- How those values are assigned to IR, Red, and Green based on current config
- Statistics for all three channels (min, max, average)
- Validation warnings if values are outside expected range (10k-500k)

## How to Fix Your Device

### Step 1: Connect and Check Logs
1. Open the app and connect to your Oralable device
2. Go to Settings → View Logs
3. Look for messages like:
   ```
   🔍 Sample 0 raw values:
      Pos 0 [XX XX XX XX] = 123456
      Pos 1 [XX XX XX XX] = 234567
      Pos 2 [XX XX XX XX] = 345678
   ```

### Step 2: Identify Correct Order
PPG sensors typically produce values in these ranges when in contact with tissue:
- **IR LED**: Usually highest, 100k-400k (most sensitive to blood flow)
- **Red LED**: Medium-high, 80k-300k (used for SpO2)
- **Green LED**: Variable, 50k-250k (used for heart rate)

Look at the three position values:
- The **highest** value is likely IR
- The **second highest** is likely Red  
- The **lowest** is likely Green

### Step 3: Test Channel Orders
1. Go to Settings → PPG Configuration (Debug)
2. Try different "Channel Order" options from the picker
3. Watch the logs to see:
   ```
   📈 IR    Stats: Min=150000, Max=180000, Avg=165000
   📈 Red   Stats: Avg=120000
   📈 Green Stats: Avg=80000
   ```
4. When values stabilize and stay consistent, you've found the right order

### Step 4: Validation Checks
✅ **Good signs:**
- IR values are highest (100k-400k range)
- Red values are medium (80k-300k range)
- Values are stable and not jumping wildly
- No validation warnings in logs

❌ **Bad signs:**
- Values outside 10k-500k range
- Values jumping randomly between extremes
- All three channels showing similar values
- Validation warnings appearing

## Expected Value Ranges

### When Sensor is in Good Contact:
```
IR:    150,000 - 300,000 (typical)
Red:   100,000 - 250,000 (typical)  
Green:  50,000 - 200,000 (typical)
```

### When Sensor is NOT in Contact:
```
All channels: < 10,000 or > 500,000 (saturation)
```

### Signal Quality Indicators:
- **AC Component**: 1-5% of DC value (pulsatile variation)
- **Heart Rate**: Should be detectable in IR signal (60-100 BPM typical)
- **Stability**: Values should vary smoothly, not jump randomly

## Common Issues

### Issue 1: All Channels Show Low Values (< 10k)
**Cause**: LED power too low or sensor not in contact  
**Fix**: Check device firmware settings, ensure good skin contact

### Issue 2: All Channels Saturated (> 500k)
**Cause**: LED power too high  
**Fix**: Reduce LED current in firmware configuration

### Issue 3: Values Jump Randomly
**Cause**: Wrong channel order in parsing  
**Fix**: Try different channel orders until values stabilize

### Issue 4: No AC Component (Flat Signal)
**Cause**: Poor contact or wrong measurement site  
**Fix**: Improve sensor contact, try different location

## Firmware References

Based on typical PPG sensor implementations:
- **MAX30102**: Default order is Red, IR (2 channels only)
- **AFE4404**: Configurable, but often IR, Red, Green
- **MAX30101**: Can be configured for any order

Your device appears to use a 3-channel configuration with:
- 244-byte packets
- 4-byte header
- 20 samples per packet
- 12 bytes per sample (3 × UInt32 little-endian)

## Testing Protocol

1. **Baseline Test**: With sensor in open air
   - All values should be < 10,000
   - No pulsatile signal

2. **Contact Test**: Press sensor firmly against fingertip
   - Values should jump to 50k-400k range
   - Should see different values for each channel
   - Values should stabilize within 2-3 seconds

3. **Signal Test**: Hold steady for 10 seconds
   - Should see rhythmic variation (heart beat)
   - AC component should be 1-5% of DC
   - Heart rate should be detectable

4. **Validation**: Compare to known good measurement
   - Use pulse oximeter on same finger
   - Heart rates should match within ±3 BPM

## Default Configuration

The app now defaults to **IR, Red, Green** ordering, which is the most common configuration. If this doesn't work, systematically try each option until you find stable readings.

## Support

If you still can't get stable readings after trying all channel orders:
1. Check firmware version (Settings → About → Firmware Version)
2. Review firmware source code at: https://github.com/johna67/tgm_firmware
3. Look for PPG data packet structure in firmware documentation
4. Verify BLE characteristic UUID is correct (3A0FF001-98C4-46B2-94AF-1AEE0FD4C48E)

Last updated: November 6, 2025
