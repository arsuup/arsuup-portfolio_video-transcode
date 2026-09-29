#!/usr/bin/env bash
set -euo pipefail

SRC=in.mp4
OUT=out
mkdir -p "$OUT"

SRC_W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=p=0 "$SRC")
SRC_H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$SRC")

SHORT=$(( SRC_W < SRC_H ? SRC_W : SRC_H ))

# bordel
LADDER="2160:16000k:192k 1440:8000k:192k 1080:6000k:192k 720:2800k:128k 480:1400k:96k 144:200k:48k"

printf '#EXTM3U\n#EXT-X-VERSION:3\n' > "$OUT/index.m3u8"

for r in $LADDER; do
  IFS=: read -r H VB AB <<< "$r"

  if [ "$H" -gt "$SHORT" ]; then continue; fi

  BUF=$(( ${VB%k} * 2 ))k
  BW=$(( (${VB%k} + ${AB%k}) * 1000 ))

  ffmpeg -y -i "$SRC" \
    -vf "scale='if(gt(iw,ih),-2,${H})':'if(gt(iw,ih),${H},-2)'" \
    -c:v libx264 -preset veryfast -profile:v main \
    -b:v "$VB" -maxrate "$VB" -bufsize "$BUF" \
    -force_key_frames "expr:gte(t,n_forced*6)" -sc_threshold 0 \
    -c:a aac -b:a "$AB" -ac 2 \
    -f hls -hls_time 6 -hls_playlist_type vod \
    -hls_segment_filename "$OUT/${H}_%03d.ts" \
    "$OUT/${H}p.m3u8"

  RES=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=s=x:p=0 "$OUT/${H}_000.ts" | sed -n '1p')

  printf '#EXT-X-STREAM-INF:BANDWIDTH=%s,RESOLUTION=%s\n%sp.m3u8\n' \
    "$BW" "$RES" "$H" >> "$OUT/index.m3u8"
done
