#!/bin/bash
# Lofi Stream - streams GitHub Pages site to YouTube
# Usage: YOUTUBE_KEY=xxxx ./stream.sh

set -e

# Config
DISPLAY_NUM=99
RESOLUTION="1280x720"
FPS=30
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"
PAGE_URL="https://ldraney.github.io/lofi-stream/"

# Check for YouTube stream key
if [ -z "$YOUTUBE_KEY" ]; then
    echo "ERROR: YOUTUBE_KEY environment variable not set"
    echo "Usage: YOUTUBE_KEY=your-stream-key ./stream.sh"
    exit 1
fi

echo "Starting lofi stream..."

# Kill any existing processes
pkill -f "Xvfb :$DISPLAY_NUM" 2>/dev/null || true
pkill -f "chromium.*lofi-stream" 2>/dev/null || true
pkill -f "ffmpeg.*rtmp" 2>/dev/null || true
sleep 2

# Start virtual display
echo "Starting Xvfb..."
Xvfb :$DISPLAY_NUM -screen 0 ${RESOLUTION}x24 &
XVFB_PID=$!
sleep 2

export DISPLAY=:$DISPLAY_NUM

# Start PulseAudio for audio capture
echo "Starting PulseAudio..."
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
sleep 1

# Create virtual audio sink
pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=VirtualSpeaker 2>/dev/null || true
pactl set-default-sink virtual_speaker 2>/dev/null || true
sleep 1

# Start Chromium in kiosk mode
echo "Starting Chromium..."
chromium-browser \
    --no-sandbox \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-dev-shm-usage \
    --kiosk \
    --autoplay-policy=no-user-gesture-required \
    --window-size=1280,720 \
    --window-position=0,0 \
    "$PAGE_URL" &
CHROME_PID=$!
sleep 5

# Simulate click to start audio (Web Audio API needs user interaction in some cases)
# Using xdotool if available
if command -v xdotool &> /dev/null; then
    xdotool mousemove 960 540 click 1
fi
sleep 2

# Start streaming with ffmpeg
echo "Starting ffmpeg stream to YouTube..."
ffmpeg \
    -f x11grab -video_size $RESOLUTION -framerate $FPS -i :$DISPLAY_NUM \
    -f pulse -i virtual_speaker.monitor \
    -c:v libx264 -preset veryfast -b:v 2500k -minrate 2500k -maxrate 2500k -bufsize 2500k -x264-params "nal-hrd=cbr:force-cfr=1" -pix_fmt yuv420p -g 60 \
    -c:a aac -b:a 128k -ar 44100 \
    -f flv "${YOUTUBE_URL}/${YOUTUBE_KEY}"

# Cleanup on exit
cleanup() {
    echo "Cleaning up..."
    kill $CHROME_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    pulseaudio --kill 2>/dev/null || true
}
trap cleanup EXIT
