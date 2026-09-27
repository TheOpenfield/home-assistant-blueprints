#!/bin/sh
# Beendet die laufende Aufnahme per SIGINT, damit ffmpeg die MP4-Datei sauber abschliesst.
PIDFILE=/config/kamera/rec.pid
LOG=/config/kamera/rec.log
[ -f "$PIDFILE" ] || exit 0
PID=$(cat "$PIDFILE")
kill -INT "$PID" 2>/dev/null
i=0
while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 10 ]; do i=$((i+1)); sleep 1; done
if kill -0 "$PID" 2>/dev/null; then kill -9 "$PID" 2>/dev/null; fi
rm -f "$PIDFILE"
CUR=$(cat /config/kamera/rec.current 2>/dev/null)
if [ -n "$CUR" ] && [ -f "$CUR" ]; then
  echo "$(date '+%F %T') STOP  $CUR ($(wc -c < "$CUR") bytes)" >> "$LOG"
fi
exit 0
