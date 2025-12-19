#!/bin/bash
# Lofi Stream - streams GitHub Pages site to YouTube
# Usage: YOUTUBE_KEY=xxxx ./stream.sh

set -e

# Config - 720p for smoother streaming on 2 vCPU
DISPLAY_NUM=99
RESOLUTION="1280x720"
FPS=24
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"
PAGE_URL="https://ldraney.github.io/lofi-stream-youtube/"

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

# PulseAudio setup (shared with other streams - don't start new instance)
echo "Setting up PulseAudio..."
export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p $XDG_RUNTIME_DIR

# Ensure PulseAudio is running (only start if not already running)
pulseaudio --check || pulseaudio --start --exit-idle-time=-1
sleep 2

# Fix 1: Clear stream-restore database to prevent PulseAudio from "remembering" wrong routing
rm -f ~/.config/pulse/*-stream-volumes.tdb 2>/dev/null || true

# Export PULSE_SERVER for ffmpeg
export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native

# Create virtual audio sink if it doesn't exist and set as default
echo "Setting up audio routing..."
if ! pactl list sinks short 2>/dev/null | grep -q "	virtual_speaker	"; then
    pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=VirtualSpeaker 2>/dev/null || true
fi
pactl set-default-sink virtual_speaker 2>/dev/null || true
sleep 1

# Start Chromium in kiosk mode
# Fix 2: PULSE_SINK forces audio to correct sink from the start
echo "Starting Chromium..."
PULSE_SINK=virtual_speaker chromium-browser \
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

# Fix 3: Aggressive audio routing - immediate check with retries, then background monitor
route_audio() {
    local retries=5
    local i=0
    while [ $i -lt $retries ]; do
        SINK_INPUT=$(pactl list sink-inputs 2>/dev/null | grep -B 20 "window.x11.display = \":$DISPLAY_NUM\"" | grep "Sink Input" | grep -oP '#\K\d+' | tail -1 || true)
        if [ -n "$SINK_INPUT" ]; then
            pactl move-sink-input $SINK_INPUT virtual_speaker 2>/dev/null && echo "Audio routed to virtual_speaker (attempt $((i+1)))" && return 0
        fi
        sleep 1
        i=$((i+1))
    done
    echo "Warning: Could not find sink-input for display :$DISPLAY_NUM after $retries attempts"
}

# Immediate routing attempt with retries
echo "Routing audio..."
route_audio

# Background audio routing monitor - keeps audio routed correctly
audio_monitor() {
    while true; do
        SINK_INPUT=$(pactl list sink-inputs 2>/dev/null | grep -B 20 "window.x11.display = \":$DISPLAY_NUM\"" | grep "Sink Input" | grep -oP '#\K\d+' | tail -1 || true)
        if [ -n "$SINK_INPUT" ]; then
            CURRENT=$(pactl list sink-inputs 2>/dev/null | grep -A 5 "Sink Input #$SINK_INPUT" | grep "Sink:" | awk '{print $2}' || true)
            EXPECTED=$(pactl list sinks short 2>/dev/null | grep "	virtual_speaker	" | cut -f1 || true)
            if [ -n "$EXPECTED" ] && [ "$CURRENT" != "$EXPECTED" ]; then
                pactl move-sink-input $SINK_INPUT virtual_speaker 2>/dev/null && echo "Audio rerouted to virtual_speaker"
            fi
        fi
        sleep 5
    done
}
audio_monitor &
echo "Started audio monitor"

# Start streaming with ffmpeg - with proper buffering
echo "Starting ffmpeg stream to YouTube..."
PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native ffmpeg \
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
