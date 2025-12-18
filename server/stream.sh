#!/bin/bash
# Lofi Stream - streams GitHub Pages site to YouTube
# Usage: YOUTUBE_KEY=xxxx ./stream.sh

set -e

# Config - 720p for smoother streaming on 2 vCPU
DISPLAY_NUM=99
RESOLUTION="1280x720"
FPS=24
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
pulseaudio --kill 2>/dev/null || true
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
sleep 2

# Create virtual audio sink and set as default
echo "Setting up audio routing..."
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

# Wait for page to fully load
echo "Waiting for page to load..."
sleep 8

# Simulate multiple clicks to ensure audio starts
echo "Triggering audio start..."
if command -v xdotool &> /dev/null; then
    xdotool mousemove 640 360 click 1
    sleep 1
    xdotool key space
    sleep 1
    xdotool mousemove 640 360 click 1
fi
sleep 3

# Ensure Chrome audio goes to virtual speaker
pactl list short sink-inputs | awk '{print $1}' | xargs -I {} pactl move-sink-input {} virtual_speaker 2>/dev/null || true

# Start streaming with ffmpeg - with proper buffering
echo "Starting ffmpeg stream to YouTube..."
ffmpeg \
    -thread_queue_size 1024 \
    -f x11grab -video_size $RESOLUTION -framerate $FPS -draw_mouse 0 -i :$DISPLAY_NUM \
    -thread_queue_size 1024 \
    -f pulse -i virtual_speaker.monitor \
    -c:v libx264 -preset ultrafast -tune zerolatency \
    -b:v 1500k -maxrate 1500k -bufsize 3000k \
    -pix_fmt yuv420p -g 48 \
    -c:a aac -b:a 128k -ar 44100 \
    -flvflags no_duration_filesize \
    -f flv "${YOUTUBE_URL}/${YOUTUBE_KEY}"

# Cleanup on exit
cleanup() {
    echo "Cleaning up..."
    kill $CHROME_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    pulseaudio --kill 2>/dev/null || true
}
trap cleanup EXIT
