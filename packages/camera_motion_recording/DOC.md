# Motion-Triggered USB Webcam Recording

## Overview

Turns a plain USB webcam attached to a Home Assistant OS host into a motion-triggered
recorder, without installing any add-on. When the motion sensor fires and nobody is home,
`ffmpeg` records an H.264 clip to `/share/kamera/`, browsable in the HA Media Browser.

Key properties:

- **Nothing runs while idle.** No add-on, no permanent stream, no background daemon.
  `ffmpeg` is launched on demand and exits when the recording ends.
- **Recording length follows the sensor.** A minimum of 30 seconds, then it keeps running
  until the motion sensor clears again, capped at 30 minutes.
- **Records only when nobody is home**, gated by `zone.home` plus a manual arm switch.
- **Manual recording on a toggle.** Flip it on to start, off to stop, with a 30-minute
  self-shutoff.
- **Push notification when a recording starts**, without HA Cloud.
- **Hardware H.264 encoding** via the Raspberry Pi's `h264_v4l2m2m` encoder, so CPU load
  stays negligible.
- **Automatic retention**, clips older than 90 days are deleted nightly.

Deployed and verified on Home Assistant OS 2026.7.4, Raspberry Pi 4 (64-bit),
Core running as root with access to `/dev/video0`.

## Why no add-on

The obvious alternatives were considered and rejected for this host:

| Option | Verdict |
| --- | --- |
| `camera:` platform `ffmpeg` | `camera.record` needs a source PyAV can open. A v4l2 argument string is not a URL, so recording does not work. |
| go2rtc add-on | Technically the best option (live view *and* recording simultaneously, plus real lookback), but requires a third-party repository and a permanent stream. |
| motionEye add-on | Own motion detection with pre-capture, but upstream unmaintained since 2023 and it runs permanently. |
| Frigate | Object detection is overkill here and heavy on a Pi 4 without a Coral. |

The host in question boots from a USB stick with known UAS stalls, so anything that writes
or encodes permanently was a bad fit. On-demand recording writes only when something
actually happens.

## Measured hardware behaviour

These numbers came from measurements on the real device, not from datasheets. They are the
reason the configuration looks the way it does.

- **Resolution is capped at 640x480.** Requesting 800x600 silently yields 640x480 again.
  Supported: `640x480`, `640x400`, `640x360`, `352x288`, `320x240`, `176x144`, `160x120`,
  in both MJPEG and YUYV.
- **Frame rate depends on light.** The camera lengthens exposure in dim conditions and
  halves the frame rate to compensate. Same request, two different results:

  | requested | good light | dim light |
  | --- | --- | --- |
  | 30 fps | 29.6 fps | 15.0 fps |
  | 15 fps | 14.8 fps | 8.7 fps |

  Auto-exposure keeps adjusting during the recording, so a light switching on mid-clip is
  compensated within about a second. Only the very first frames after opening the device
  are dark.
- **Hardware encoding is 4x more efficient than software.** Same 3-second scene:
  `h264_v4l2m2m` 243 KB versus `libx264 -preset ultrafast` 962 KB.
- **Only one process can open `/dev/video0`.** This rules out having a live camera entity
  alongside recording, and is why the automation uses `mode: single`.
- **The webcam microphone is not reachable via ALSA** (`hw:1,0` returns "Resource busy",
  HA's PulseAudio server holds the device). It works through PulseAudio instead. Audio
  support is implemented but disabled by default, see below.

## Files

```
packages/camera_motion_recording/
  DOC.md                        this file
  configuration-snippet.yaml    append to configuration.yaml (needs a Core restart)
  automations-snippet.yaml      append to automations.yaml (reload is enough)
  scripts/
    rec_start.sh                launches ffmpeg detached, stores the PID
    rec_stop.sh                 SIGINT so the MP4 is finalised properly
    cleanup.sh                  nightly retention and log rotation
```

## Setup instructions

### Step 1: Verify the camera is detected

On the host, via the Terminal & SSH add-on:

```sh
ha hardware info --raw-json | jq -r '.data.devices[]
  | select(.subsystem=="video4linux")
  | [.name, .dev_path, (.attributes.ID_VENDOR_ID//"-"), (.attributes.ID_MODEL_ID//"-")]
  | @tsv'
```

The camera should show up as `/dev/video0` with its vendor and product ID. On a Pi, the
`video10`-`video31` entries are the built-in hardware codecs, not cameras.

### Step 2: Install the scripts

Copy the three files from `scripts/` to `/config/kamera/` on the host and make them
executable:

```sh
mkdir -p /config/kamera
chmod +x /config/kamera/rec_start.sh /config/kamera/rec_stop.sh /config/kamera/cleanup.sh
```

### Step 3: Extend `configuration.yaml`

Append the contents of `configuration-snippet.yaml`. If a `homeassistant:` block already
exists, merge `media_dirs` into it instead of adding a second one.

Then restart Home Assistant Core. This restart is unavoidable, `shell_command` entries are
not reloadable.

### Step 4: Add the automations

Append the contents of `automations-snippet.yaml` to `automations.yaml`, adjust
`binary_sensor.eve_motion_d87d` to your own motion sensor, then go to
**Developer Tools -> YAML -> Reload Automations**. No restart needed for this part.

### Step 5: Arm and test

1. **Settings -> Devices & Services -> Helpers -> Kamera Eingang aktiv** -> on.
2. Open the automation and press **Run**. This skips the conditions, so you can test the
   whole action chain without leaving the house: recording starts, the push notification
   goes out within a second, the recording then follows the sensor. Expect at least 30
   seconds of video.
3. **Media -> kamera** should now list `eingang_YYYY-MM-DD_HH-MM-SS.mp4`.

## Manual recording

`input_boolean.kamera_eingang_manuell` records on demand: on starts, off stops. Put the
toggle on a dashboard and it doubles as the "is it recording" indicator.

Three details make this work reliably:

- **The motion automation yields to it.** Both share the same PID file, so without the
  `kamera_eingang_manuell is off` condition they would kill each other's recordings.
  Manual always wins, because it is an explicit user action.
- **A 30-minute self-shutoff** is folded into the same automation as a third trigger.
  It is not cosmetic: because the motion automation is blocked while the toggle is on, a
  forgotten switch would silently disable motion recording forever. Turning the toggle off
  also fires the stop branch, so the recording ends cleanly.
- **`mode: queued`** so a quick on-off sequence never drops the stop.

Manual recordings use the same `eingang_*.mp4` naming, so the 90-day retention covers them.

## Push notification

The motion automation sends a notification right after starting the recording, so it fires
exactly in the interesting case: motion, nobody home, camera armed. Manual recordings
deliberately do **not** notify, that would only be noise about your own action.

This needs **no Nabu Casa subscription**. The companion app registers a push token with the
Home Assistant project's free push proxy at `mobile-apps.home-assistant.io`, which forwards
to Firebase (Android) or APNS (iOS). Two consequences:

- The host needs **outbound** internet access to reach the proxy. Inbound is not required.
- The message reaches the phone through Google's or Apple's infrastructure, so the phone
  does **not** need to be able to reach Home Assistant. A VPN such as Tailscale is only
  needed afterwards, to open the app and watch the clip.

`ttl: 0` and `priority: high` make Android deliver immediately instead of waiting for the
next doze window. `continue_on_error: true` on the notify action is deliberate: a wrong
service name or a failed delivery must never abort the recording.

No preview image is attached. At that moment ffmpeg holds the camera and a second access
would fail. A thumbnail is only possible in a second notification after the clip is
finalised, extracted from the finished file.

## Tuning

Every knob lives in the variable block at the top of `rec_start.sh` and takes effect
**immediately, without a restart**, because the script is read fresh on each invocation:

```sh
FPS=15          SIZE=640x480      BITRATE=1000k
MAXSEC=1830     AUDIO=0           AUDIO_BITRATE=64k
```

A lower frame rate at a fixed bitrate means more bits per frame and a visibly cleaner
image, which is usually the better trade for a door camera.

The maximum length exists in two places and both need to match: `MAXSEC` in the script is
the hard ffmpeg limit (set 30 s above the intended maximum), while `timeout` in the
automation's `wait_template` is the regular one. `00:00:30` delay plus `00:29:30` timeout
gives 30 minutes total.

### Enabling audio

Set `AUDIO=1` in `rec_start.sh` and adjust `AUDIO_SRC` to your device. List the available
PulseAudio sources from inside the Core container with `ffmpeg -sources pulse`; the webcam
appears as something like `alsa_input.usb-046d_0804_<serial>-02.mono-fallback`.

Note that recording audio is legally far more restricted than recording video. Under German
law, recording the non-public spoken word without the speakers' consent is a criminal
offence (§ 201 StGB), and that applies to visitors at your own front door.

## Verification

`/config/kamera/rec.log` records every start and stop with the resulting file size:

```
21:51:05 START /share/kamera/eingang_2026-08-05_21-51-05.mp4
21:53:16 STOP  /share/kamera/eingang_2026-08-05_21-51-05.mp4 (8146946 bytes)
```

Automation traces are the second source of truth, but note that HA writes
`/config/.storage/trace.saved_traces` **with a delay**, so the most recent run is usually
missing from the file. A restart flushes it. A blocked run looks like this and names the
condition that stopped it:

```
condition/0 -> {"result": true}
condition/1 -> {"result": false}
```

Expect `missing picture in access unit` and `no frame!` when probing a clip with ffprobe.
The hardware encoder emits a leading access unit carrying only parameter sets. All frames
are present and every player handles it.

## Limitations

- **No live view.** The camera device is exclusive; a live entity would block recordings.
  If you want both, go2rtc is the answer.
- **No lookback.** Recording starts when the trigger fires, roughly a second is lost while
  the camera initialises. Real pre-roll requires a permanently running stream.
- **Night vision.** A webcam without IR sees nothing in the dark. Pairing the camera with
  an existing motion-activated light on the same sensor solves this in practice.
- **Clip length depends on the sensor's hold time.** The Eve Motion used here holds for
  about 129 s, so a single walk-past produces a clip of roughly 2 minutes (~8 MB). At a
  30-minute cap the theoretical maximum is around 126 MB per clip.

## Notes

- `shell_command` entries must not contain Jinja templates combined with shell syntax.
  Such commands fail silently with `return code: 1`, and HA does not log stdout or stderr,
  so the actual error is invisible. Keep all logic in a script and let `shell_command` only
  call it. As a bonus, script changes then need no restart.
- Recordings are written to the same storage device Home Assistant itself runs from. On a
  host booting from a USB stick, factor in the extra write load and keep a backup.
