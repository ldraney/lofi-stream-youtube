# lofi-stream

Stream a lofi HTML page from GitHub Pages to YouTube Live via a Hetzner VPS.

## Project Goal

A 24/7 YouTube live stream displaying a lofi-style HTML page with ambient visuals and music.

## Architecture

```
GitHub Pages (static HTML)
        │
        ▼
Hetzner VPS (CX22 ~€4.50/mo)
  ├── Xvfb (virtual display)
  ├── Chromium (renders page)
  └── ffmpeg (captures + RTMP stream)
        │
        ▼
YouTube Live (RTMP ingest)
```

## Definition of Done

The project is complete when:
- [ ] YouTube live stream is running 24/7
- [ ] Stream displays the lofi HTML page with visuals
- [ ] Audio is playing (lofi beats)
- [ ] Stream auto-recovers from crashes (systemd or supervisor)
- [ ] Minimal maintenance required

---

## Roadmap

### Phase 1: Lofi HTML Page
- [x] Create basic HTML/CSS lofi page
- [x] Add ambient visuals (rain, particles, animations)
- [x] Add lofi audio (Web Audio API generative - no copyright issues!)
- [x] Deploy to GitHub Pages - https://ldraney.github.io/lofi-stream/
- [ ] Test page loads and plays correctly

### Phase 2: Hetzner VPS Setup
- [x] Provision Hetzner VPS (Ubuntu 24.04, 2GB RAM)
- [x] SSH access configured (5.78.42.22)
- [x] Install dependencies: Xvfb, Chromium, ffmpeg, pulseaudio, xdotool
- [ ] Test headless browser can render the page

### Phase 3: Streaming Pipeline
- [x] Create streaming script (start Xvfb, launch Chromium, run ffmpeg)
- [x] Configure ffmpeg for YouTube RTMP output
- [ ] Test stream to YouTube (unlisted first)
- [ ] Tune encoding settings (resolution, bitrate, audio)

### Phase 4: Production Hardening
- [x] Create systemd service for auto-start
- [x] Add crash recovery / restart logic (Restart=always)
- [ ] Set up basic monitoring (is stream alive?)
- [ ] Go live (public stream)

### Phase 5: Polish (Optional)
- [ ] Add stream title/description rotation
- [ ] Dynamic visuals based on time of day
- [ ] Chat integration or viewer count overlay
- [ ] Multiple audio sources / playlist

---

## Key Files

```
lofi-stream/
├── CLAUDE.md           # This file
├── docs/               # GitHub Pages lofi site (renamed from site/)
│   ├── index.html      # Main page with visuals + Web Audio API
│   └── style.css       # All animations and styling
├── server/             # VPS scripts (to be created)
│   ├── stream.sh       # Main streaming script
│   ├── setup.sh        # Server setup script
│   └── lofi-stream.service  # systemd unit
└── README.md
```

## Tech Stack

- **Frontend:** HTML, CSS, vanilla JS (keep it simple)
- **Audio:** Embedded MP3s or Web Audio API generated lofi
- **Server:** Ubuntu 22.04 on Hetzner CX22
- **Streaming:** Xvfb + Chromium + ffmpeg + PulseAudio
- **Hosting:** GitHub Pages (free)

## YouTube Setup Notes

1. Go to YouTube Studio → Go Live → Stream
2. Get Stream Key (keep secret!)
3. RTMP URL: `rtmp://a.rtmp.youtube.com/live2`
4. Set stream to 720p or 1080p, 30fps is fine for lofi

## Useful Commands

```bash
# Start virtual display
Xvfb :99 -screen 0 1920x1080x24 &

# Launch Chromium on virtual display
DISPLAY=:99 chromium --kiosk --autoplay-policy=no-user-gesture-required https://yourpage.github.io/lofi

# Stream to YouTube
ffmpeg -f x11grab -video_size 1920x1080 -i :99 \
       -f pulse -i default \
       -c:v libx264 -preset veryfast -b:v 3000k \
       -c:a aac -b:a 128k \
       -f flv rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY
```

## Current Status

**Phase:** 3 - Ready to test stream
**Live Site:** https://ldraney.github.io/lofi-stream/
**Server:** 5.78.42.22 (scripts deployed to /opt/lofi-stream/)
**Next Action:** Get YouTube stream key and test!
