#!/usr/bin/env bash
# Repository audit script - cleaned (UNIX line endings)
# Usage:
#   chmod +x audit_repo.sh
#   ./audit_repo.sh
# Output: audit_report.txt in repo root

set -euo pipefail

OUT="audit_report.txt"
echo "Repository audit generated at $(date -u +"%Y-%m-%d %H:%M:%S UTC")" > "$OUT"
echo "" >> "$OUT"

echo "1) Duplicate type candidates (DeviceState, DeviceStateResult, MetricType, HistoricalAppMode)" >> "$OUT"
git grep -nE "enum\s+(DeviceState|MetricType|HistoricalAppMode)|struct\s+DeviceStateResult" -- . || true
echo >> "$OUT"

echo "2) All publisher-forwarder occurrences (var ...Publisher)" >> "$OUT"
git grep -nE "var\s+[A-Za-z0-9_]+Publisher" -- . || true
echo >> "$OUT"

echo "3) Files referencing isConnectedPublisher specifically" >> "$OUT"
git grep -n "isConnectedPublisher" -- . || true
echo >> "$OUT"

echo "4) Files with Logger.shared.* calls (hot logging sites)" >> "$OUT"
git grep -n "Logger.shared\." -- . || true
echo >> "$OUT"

echo "5) Files referencing sensorDataHistory and sensor-related arrays" >> "$OUT"
git grep -n "sensorDataHistory\|ppgHistory\|accelHistory\|ppgRedValue\|ppgIRValue\|ppgGreenValue" -- . || true
echo >> "$OUT"

echo "6) Files with ForEach / Chart / LineMark that could re-render large arrays" >> "$OUT"
git grep -nE "ForEach|LineMark|Chart" -- . || true
echo >> "$OUT"

echo "7) Look for convertToSensorData / updatePPGHistory / updateAccelHistory" >> "$OUT"
git grep -nE "convertToSensorData|updatePPGHistory|updateAccelHistory|processBatchAsync|startAsyncBatchProcessing" -- . || true
echo >> "$OUT"

echo "8) Search for old enum case names" >> "$OUT"
git grep -n "\.onMuscle\b\|\.onChargerIdle\b\|\.offChargerIdle\b" -- . || true
echo >> "$OUT"

echo "9) Search for getRecommendedTimeRange usages" >> "$OUT"
git grep -n "getRecommendedTimeRange" -- . || true
echo >> "$OUT"

echo "10) Swift files accidentally in Copy Bundle Resources (scan project.pbxproj resources sections)" >> "$OUT"
# Grep project file for Copy Bundle Resources or Resources phase references
if [ -f "OralableApp/OralableApp.xcodeproj/project.pbxproj" ]; then
  awk '/Begin PBXResourcesBuildPhase/,/End PBXResourcesBuildPhase/' OralableApp/OralableApp.xcodeproj/project.pbxproj || true
  # Look for .swift inside project file (quick heuristic)
  grep -nE "\.swift\"" OralableApp/OralableApp.xcodeproj/project.pbxproj || true
else
  echo "Project file not found at OralableApp/OralableApp.xcodeproj/project.pbxproj" >> "$OUT"
fi
echo >> "$OUT"

echo "11) Largest Swift files (top 20 by lines)" >> "$OUT"
find . -name "*.swift" -print0 | xargs -0 wc -l | sort -rn | head -n 20 || true
echo >> "$OUT"

echo "12) Basic sanity: list recently changed files (last 5 commits)" >> "$OUT"
git --no-pager show --name-only --pretty="" HEAD~4..HEAD || true
echo >> "$OUT"

echo "Audit complete." >> "$OUT"
echo "Wrote $OUT"
ls -l "$OUT"