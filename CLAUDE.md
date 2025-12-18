# lofi-stream-youtube

YouTube streaming component (Night City theme) of the lofi-stream project. Captures a GitHub Pages lofi site and streams it 24/7 to YouTube Live.

> **Full project docs & roadmap:** [lofi-stream-docs](https://github.com/ldraney/lofi-stream-docs)
> **Sister project:** [lofi-stream-twitch](https://github.com/ldraney/lofi-stream-twitch) (Coffee Shop theme)

## Secrets

```bash
# Stream key and RTMP URL
cat ~/api-secrets/lofi-stream/platforms/youtube.env

# SSH key for servers
~/api-secrets/hetzner-server/id_ed25519
```

## Quick Reference

```bash
# SSH to server
ssh -i ~/api-secrets/hetzner-server/id_ed25519 root@5.78.42.22

# Check stream status
systemctl status lofi-stream

# View logs
journalctl -u lofi-stream -f

# Restart stream
systemctl restart lofi-stream

# Check RTMP connection
ss -tn | grep 1935

# Monitor resources
top -bn1 | head -15 && free -h
```

## Dev Server (Testing)

Use the dev server (5.78.42.22 as `lofidev` user) to test changes before deploying to production.

```bash
# Deploy this repo to dev server
make deploy-dev

# Check what's deployed
make dev-status

# Clean up when done testing
make cleanup-dev

# Full dev server reset (kills all processes, cleans home dir)
make dev-reset

# View reset logs
make dev-logs
```

**When to use dev server:**
- Testing changes to `docs/` (the lofi page)
- Testing changes to `server/` scripts
- Debugging stream issues without affecting production

**Dev server resets daily at 4 AM UTC** - any deployments will be cleaned up automatically.

## Current Status

| Component | Value |
|-----------|-------|
| Phase | Production (complete) |
| GitHub Pages | https://ldraney.github.io/lofi-stream/ |
| Server | 5.78.42.22 |
| Resolution | 720p @ 24fps |
| Bitrate | 1.5 Mbps video, 128k audio |
| Service | systemd (Restart=always) |

## Repository Structure

```
lofi-stream-youtube/
├── CLAUDE.md              # This file
├── Makefile               # Dev server deploy/cleanup
├── README.md              # Public readme
├── status.sh              # Quick status check
├── docs/                  # GitHub Pages lofi site
│   ├── index.html         # Visuals + Web Audio API
│   └── style.css          # Animations
└── server/                # VPS scripts
    ├── stream.sh          # Main streaming script
    ├── setup.sh           # Server setup
    ├── lofi-stream.service # systemd unit
    └── health-check.sh    # Health monitoring
```

## YouTube Setup

1. Go to YouTube Studio > Go Live > Stream
2. Get Stream Key (keep secret!)
3. RTMP URL: `rtmp://a.rtmp.youtube.com/live2`
4. Recommended: 720p, 24-30fps for lofi content

## Definition of Done (YouTube Component)

- [x] YouTube live stream running 24/7
- [x] Stream displays lofi HTML page with visuals
- [x] Audio playing (Web Audio API generative)
- [x] Auto-recovery from crashes (systemd)
- [x] Minimal maintenance required

---

## Lessons Learned

### PulseAudio + ffmpeg Audio Issue

**Problem:** YouTube stream had video but NO audio.

**Symptoms:**
- `pactl list sink-inputs` showed Chromium playing audio
- ffmpeg logs showed "reading" from `virtual_speaker.monitor`
- BUT `pactl list source-outputs` was **empty**

**Root Cause:** ffmpeg didn't have `PULSE_SERVER` environment variable set under systemd.

**Fix:**
```bash
export XDG_RUNTIME_DIR=/run/user/0
export PULSE_SERVER=unix:/run/user/0/pulse/native
```

**Debugging:**
```bash
# Verify ffmpeg is ACTUALLY connected to PulseAudio
pactl list source-outputs  # Should show ffmpeg

# Test audio levels
ffmpeg -f pulse -i virtual_speaker.monitor -af volumedetect -t 2 -f null -
```

**Key Insight:** Just because ffmpeg says `Input #1, pulse` doesn't mean it's receiving audio. Always verify with `pactl list source-outputs`.

---

## Useful Commands

```bash
# Start virtual display manually
Xvfb :99 -screen 0 1280x720x24 &

# Launch Chromium on virtual display
DISPLAY=:99 chromium --kiosk --autoplay-policy=no-user-gesture-required \
    https://ldraney.github.io/lofi-stream/

# Stream to YouTube manually
ffmpeg -f x11grab -video_size 1280x720 -framerate 24 -i :99 \
       -f pulse -i virtual_speaker.monitor \
       -c:v libx264 -preset ultrafast -b:v 1500k \
       -c:a aac -b:a 128k \
       -f flv rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY
```
