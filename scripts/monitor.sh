#!/bin/bash
#
# monitor.sh - check disk, memory and CPU load against thresholds
#
# Writes to ~/capstone/logs/alerts.log:
#   one ALERT line for every metric that crossed its threshold, or
#   one OK line if every metric is healthy.
#
# Usage: ./monitor.sh

# ---------- Thresholds (edit these to tune the alerts) ----------
DISK_THRESHOLD=80       # ALERT if root (/) disk usage is ABOVE this percent
MEM_THRESHOLD=500       # ALERT if available memory is BELOW this many MB
LOAD_THRESHOLD=4.0       # ALERT if the 1-minute load average is ABOVE this

# ---------- Settings ----------
LOG_FILE="$HOME/capstone/logs/alerts.log"
ALERT_COUNT=0            # how many metrics are unhealthy in this run

# ---------- Helper function ----------
# Print a line with the date and time, and append it to the log file
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

mkdir -p "$(dirname "$LOG_FILE")"

# ---------- Check 1: disk usage of the root filesystem ----------
# df --output=pcent /   prints "Use%" and then e.g. " 23%"
# tail -n 1             keeps only the last line: " 23%"
# tr -d ' %'            deletes the spaces and the % sign: "23"
DISK_USAGE=$(df --output=pcent / | tail -n 1 | tr -d ' %')

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    log "ALERT: disk usage is at ${DISK_USAGE}%, threshold is ${DISK_THRESHOLD}%"
    ALERT_COUNT=$((ALERT_COUNT + 1))
fi

# ---------- Check 2: available memory in MB ----------
# free -m shows memory in MB. On the line that starts with "Mem:",
# column 7 is "available" = memory that programs can still get.
MEM_AVAILABLE=$(free -m | awk '/^Mem:/ {print $7}')

if [ "$MEM_AVAILABLE" -lt "$MEM_THRESHOLD" ]; then
    log "ALERT: available memory is at ${MEM_AVAILABLE}MB, threshold is ${MEM_THRESHOLD}MB"
    ALERT_COUNT=$((ALERT_COUNT + 1))
fi

# ---------- Check 3: 1-minute load average ----------
# /proc/loadavg looks like "0.42 0.35 0.30 1/123 4567"
# Field 1 is the load average of the last 1 minute.
LOAD_1MIN=$(awk '{print $1}' /proc/loadavg)

# Bash can only compare whole numbers, so awk compares the decimals
# and prints "yes" if the load is above the threshold.
LOAD_TOO_HIGH=$(awk -v value="$LOAD_1MIN" -v limit="$LOAD_THRESHOLD" \
    'BEGIN { if (value + 0 > limit + 0) print "yes"; else print "no" }')

if [ "$LOAD_TOO_HIGH" = "yes" ]; then
    log "ALERT: load average (1 min) is at ${LOAD_1MIN}, threshold is ${LOAD_THRESHOLD}"
    ALERT_COUNT=$((ALERT_COUNT + 1))
fi

# ---------- Summary ----------
# No alerts at all -> write a single OK line
if [ "$ALERT_COUNT" -eq 0 ]; then
    log "OK: all metrics within thresholds"
fi

exit 0
