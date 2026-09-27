#!/bin/sh
# Loescht Aufnahmen aelter als 90 Tage und abgebrochene Fragmente.
DIR=/share/kamera
LOG=/config/kamera/rec.log
find "$DIR" -maxdepth 1 -type f -name 'eingang_*.mp4' -mtime +90 -delete
find "$DIR" -maxdepth 1 -type f -name 'eingang_*.mp4' -size -20k -mmin +10 -delete
if [ -f "$LOG" ]; then tail -n 300 "$LOG" > "$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"; fi
echo "$(date '+%F %T') CLEANUP fertig, $(ls -1 "$DIR"/eingang_*.mp4 2>/dev/null | wc -l) clips" >> "$LOG"
exit 0
