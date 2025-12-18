#!/bin/bash
# Quick status check for lofi-stream-youtube
# Usage: ./status.sh

KEY=~/api-secrets/hetzner-server/id_ed25519
PROD_HOST=root@135.181.150.82

echo "Lofi Stream YouTube Status"
echo "=========================="
echo ""

# Server status
echo "Production Server (135.181.150.82):"
ssh -i $KEY -o ConnectTimeout=5 $PROD_HOST '
  echo "  Service: $(systemctl is-active lofi-stream)"

  if pgrep -f "ffmpeg.*youtube" > /dev/null; then
    echo "  ffmpeg: streaming"
  else
    echo "  ffmpeg: NOT RUNNING"
  fi

  if pgrep -f "Xvfb :99" > /dev/null; then
    echo "  Display :99: running"
  else
    echo "  Display :99: NOT RUNNING"
  fi

  CPU=$(top -bn1 | grep "Cpu(s)" | awk "{printf \"%.0f\", \$2}")
  MEM=$(free | awk "/^Mem:/ {printf \"%.0f\", \$3/\$2*100}")
  echo "  CPU: ${CPU}% | RAM: ${MEM}%"
' 2>/dev/null || echo "  Cannot connect to server"

echo ""

# GitHub Pages
echo "GitHub Pages:"
if curl -s --max-time 5 https://ldraney.github.io/lofi-stream-youtube/ | grep -q "lofi"; then
  echo "  https://ldraney.github.io/lofi-stream-youtube/ is UP"
else
  echo "  Page not accessible"
fi

echo ""
echo "YouTube: Check manually at YouTube Studio"
echo ""
echo "For full health check: ssh $PROD_HOST '/opt/scripts/check-streams.sh'"
