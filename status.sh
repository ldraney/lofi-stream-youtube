#!/bin/bash
# Quick status check for lofi stream
# Usage: ./status.sh

KEY=~/api-secrets/hetzner-server/id_ed25519
HOST=root@5.78.42.22

echo "🎵 Lofi Stream Status"
echo "===================="
echo ""

# Server status
echo "📡 Server (5.78.42.22):"
ssh -i $KEY -o ConnectTimeout=5 $HOST "
  if pgrep -f 'ffmpeg.*rtmp' > /dev/null; then
    echo '  ✓ ffmpeg: streaming'
  else
    echo '  ✗ ffmpeg: NOT RUNNING'
  fi

  if pgrep -f 'chromium.*lofi' > /dev/null; then
    echo '  ✓ chromium: running'
  else
    echo '  ✗ chromium: NOT RUNNING'
  fi

  CPU=\$(top -bn1 | grep 'Cpu(s)' | awk '{printf \"%.0f\", \$2}')
  MEM=\$(free | awk '/^Mem:/ {printf \"%.0f\", \$3/\$2*100}')
  echo \"  📊 CPU: \${CPU}% | RAM: \${MEM}%\"
" 2>/dev/null || echo "  ✗ Cannot connect to server"

echo ""

# GitHub Pages
echo "🌐 GitHub Pages:"
if curl -s --max-time 5 https://ldraney.github.io/lofi-stream/ | grep -q "lofi"; then
  echo "  ✓ https://ldraney.github.io/lofi-stream/ is UP"
else
  echo "  ✗ Page not accessible"
fi

echo ""
echo "📺 YouTube: Check manually at YouTube Studio"
echo ""
