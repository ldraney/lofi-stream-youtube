#!/bin/bash
# Server setup script for lofi-stream
# Run this on the Hetzner VPS

set -e

echo "Setting up lofi-stream server..."

# Install xdotool for mouse simulation
apt-get install -y xdotool

# Create directory
mkdir -p /opt/lofi-stream

# Copy stream script
cp /tmp/stream.sh /opt/lofi-stream/
chmod +x /opt/lofi-stream/stream.sh

# Install systemd service
cp /tmp/lofi-stream.service /etc/systemd/system/
systemctl daemon-reload

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit /etc/systemd/system/lofi-stream.service"
echo "2. Replace YOUR_STREAM_KEY_HERE with your YouTube stream key"
echo "3. Run: systemctl enable lofi-stream"
echo "4. Run: systemctl start lofi-stream"
echo ""
echo "To test manually first:"
echo "YOUTUBE_KEY=your-key /opt/lofi-stream/stream.sh"
