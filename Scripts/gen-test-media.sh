#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/TestMedia/generated"
mkdir -p "$OUT"

FFMPEG="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"

# Short synthetic clips. These are original generated files, not copyrighted media.
"$FFMPEG" -y -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=440:sample_rate=48000 \
  -t 3 -c:v libx264 -pix_fmt yuv420p -c:a aac "$OUT/h264_aac.mp4"

"$FFMPEG" -y -f lavfi -i testsrc2=size=1920x1080:rate=30 -f lavfi -i sine=frequency=550:sample_rate=48000 \
  -t 3 -c:v libx265 -pix_fmt yuv420p -c:a aac -tag:v hvc1 "$OUT/hevc_aac.mp4"

"$FFMPEG" -y -f lavfi -i testsrc2=size=640x360:rate=24 -f lavfi -i sine=frequency=330:sample_rate=44100 \
  -t 3 -c:v libx264 -c:a aac "$OUT/h264.mkv"

"$FFMPEG" -y -f lavfi -i sine=frequency=440:sample_rate=44100 -t 2 -c:a libmp3lame "$OUT/tone.mp3"
"$FFMPEG" -y -f lavfi -i sine=frequency=440:sample_rate=48000 -t 2 -c:a flac "$OUT/tone.flac"
"$FFMPEG" -y -f lavfi -i sine=frequency=440:sample_rate=48000 -t 2 -c:a libopus "$OUT/tone.opus"

# Multi-audio MKV
"$FFMPEG" -y -f lavfi -i testsrc2=size=640x360:rate=24 -t 2 -c:v libx264 -an "$OUT/silent.mp4"
"$FFMPEG" -y -i "$OUT/silent.mp4" -i "$OUT/tone.mp3" -i "$OUT/tone.flac" \
  -map 0:v -map 1:a -map 2:a -c copy "$OUT/multi_audio.mkv" || true

cat > "$OUT/sample.srt" <<'EOF'
1
00:00:00,000 --> 00:00:02,000
MacMedia test subtitle
EOF

"$FFMPEG" -y -i "$OUT/h264.mkv" -i "$OUT/sample.srt" -c copy -c:s srt "$OUT/with_subs.mkv" || cp "$OUT/h264.mkv" "$OUT/with_subs.mkv"

# Unicode filenames
cp "$OUT/h264_aac.mp4" "$OUT/فيلم عربي.mkv"
cp "$OUT/h264_aac.mp4" "$OUT/İstanbul Video.mp4"
cp "$OUT/h264_aac.mp4" "$OUT/电影.mkv"
cp "$OUT/h264_aac.mp4" "$OUT/映画.mp4"
cp "$OUT/h264_aac.mp4" "$OUT/🎬 Movie.mkv"

# Malformed / crash-resilience corpus
: > "$OUT/empty.mp4"
echo "this is not a media file" > "$OUT/random.bin"
printf 'RIFF\x00\x00\x00\x00WAVEfmt ' > "$OUT/corrupt.mp4"

echo "Generated test media in $OUT"
ls -lh "$OUT"
