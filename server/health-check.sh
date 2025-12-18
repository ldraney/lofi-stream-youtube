#!/bin/bash
# Health check for lofi stream
# Run via cron: */5 * * * * /opt/lofi-stream/health-check.sh

LOG="/var/log/lofi-health.log"

echo "=== Health Check $(date) ===" >> $LOG

# Check if ffmpeg is running
if pgrep -f "ffmpeg.*rtmp" > /dev/null; then
    echo "✓ ffmpeg: running" >> $LOG
else
    echo "✗ ffmpeg: NOT RUNNING - restarting service" >> $LOG
    systemctl restart lofi-stream
fi

# Check CPU usage
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
echo "  CPU: ${CPU}%" >> $LOG

# Check memory
MEM=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
echo "  Memory: $MEM" >> $LOG

# Check if GitHub Pages is accessible
if curl -s --max-time 5 https://ldraney.github.io/lofi-stream/ | grep -q "lofi"; then
    echo "✓ GitHub Pages: accessible" >> $LOG
else
    echo "✗ GitHub Pages: NOT ACCESSIBLE" >> $LOG
fi

echo "" >> $LOG
