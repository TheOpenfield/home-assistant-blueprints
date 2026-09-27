#!/bin/sh
# Startet eine Aufnahme der Eingangskamera im Hintergrund und merkt sich die PID.
# Aufgerufen von: shell_command.kamera_rec_start

# ======================= Einstellungen =======================
FPS=15              # angeforderte Bildrate. Bei wenig Licht regelt die Kamera
                    # selbsttaetig herunter (gemessen: 15 -> ca. 8,7 fps im Dunkeln).
SIZE=640x480        # Maximum dieser Kamera. Groessere Werte werden ignoriert.
BITRATE=1000k       # bestimmt die Dateigroesse: ca. 70 kB/s, 30 min ~ 126 MB
MAXSEC=1830         # harte Obergrenze in ffmpeg (30 min + 30 s Puffer),
                    # greift auch dann, wenn der Stop-Aufruf ausbleibt
AUDIO=0             # 0 = nur Video, 1 = Ton mit aufzeichnen.
                    # ACHTUNG: Tonaufnahme von Gespraechen Dritter faellt unter
                    # Paragraph 201 StGB. Umstellen wirkt sofort, ohne Neustart.
AUDIO_SRC=alsa_input.usb-046d_0804_F9C41580-02.mono-fallback
AUDIO_BITRATE=64k
DIR=/share/kamera
# =============================================================

PIDFILE=/config/kamera/rec.pid
LOG=/config/kamera/rec.log

mkdir -p "$DIR"

# eventuell haengende Aufnahme beenden, damit /dev/video0 frei ist
if [ -f "$PIDFILE" ]; then
  kill -INT "$(cat "$PIDFILE")" 2>/dev/null
  sleep 1
  rm -f "$PIDFILE"
fi

OUT="$DIR/eingang_$(date +%Y-%m-%d_%H-%M-%S).mp4"

if [ "$AUDIO" = "1" ]; then
  echo "$(date '+%F %T') START $OUT (mit ton)" >> "$LOG"
  ffmpeg -hide_banner -loglevel error -nostdin \
    -f v4l2 -input_format mjpeg -video_size "$SIZE" -framerate "$FPS" -i /dev/video0 \
    -f pulse -ac 1 -i "$AUDIO_SRC" \
    -t "$MAXSEC" -c:v h264_v4l2m2m -pix_fmt yuv420p -b:v "$BITRATE" \
    -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart \
    -y "$OUT" </dev/null >>"$LOG" 2>&1 &
else
  echo "$(date '+%F %T') START $OUT" >> "$LOG"
  ffmpeg -hide_banner -loglevel error -nostdin \
    -f v4l2 -input_format mjpeg -video_size "$SIZE" -framerate "$FPS" -i /dev/video0 \
    -t "$MAXSEC" -c:v h264_v4l2m2m -pix_fmt yuv420p -b:v "$BITRATE" -an \
    -movflags +faststart \
    -y "$OUT" </dev/null >>"$LOG" 2>&1 &
fi

echo $! > "$PIDFILE"
echo "$OUT" > /config/kamera/rec.current
exit 0
