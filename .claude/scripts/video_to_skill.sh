#!/usr/bin/env bash
# Downloads a video, extracts frames + an audio transcript, and lays out
# a new Claude Code skill folder (SKILL.md + assets/) from the result.
#
# Usage:
#   video_to_skill.sh <video-url> <skill-slug> [skills-dir] [frame-interval-seconds] [whisper-model]
#
# Defaults: skills-dir=.claude/skills, frame-interval-seconds=5, whisper-model=base
set -euo pipefail

VIDEO_URL="${1:?usage: video_to_skill.sh <video-url> <skill-slug> [skills-dir] [frame-interval-seconds] [whisper-model]}"
SKILL_SLUG="${2:?usage: video_to_skill.sh <video-url> <skill-slug> [skills-dir] [frame-interval-seconds] [whisper-model]}"
SKILLS_DIR="${3:-.claude/skills}"
FRAME_INTERVAL="${4:-5}"
WHISPER_MODEL="${5:-base}"
MAX_FRAMES=60

if [[ ! "$SKILL_SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: skill slug '$SKILL_SLUG' must be lowercase kebab-case (e.g. my-video-skill)" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "== working dir: $WORKDIR"

echo "== 1/5 checking dependencies"
command -v ffmpeg >/dev/null || { echo "error: ffmpeg not found" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 not found" >&2; exit 1; }

if ! python3 -c "import yt_dlp" >/dev/null 2>&1; then
  echo "   installing yt-dlp..."
  pip3 install --quiet --user yt-dlp
fi
if ! python3 -c "import faster_whisper" >/dev/null 2>&1; then
  echo "   installing faster-whisper (transcription engine)..."
  pip3 install --quiet --user faster-whisper
fi

echo "== 2/5 downloading video"
VIDEO_PATH="$WORKDIR/source.mp4"
if python3 -m yt_dlp --help >/dev/null 2>&1; then
  python3 -m yt_dlp -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b" \
    --no-playlist -o "$VIDEO_PATH" --write-info-json "$VIDEO_URL" || {
    echo "   yt-dlp failed, falling back to direct download"
    curl -sSL "$VIDEO_URL" -o "$VIDEO_PATH"
  }
else
  curl -sSL "$VIDEO_URL" -o "$VIDEO_PATH"
fi

if [[ ! -s "$VIDEO_PATH" ]]; then
  echo "error: no video was downloaded" >&2
  exit 1
fi

INFO_JSON="$(ls "$WORKDIR"/*.info.json 2>/dev/null | head -n1 || true)"
TITLE="$SKILL_SLUG"
if [[ -n "$INFO_JSON" ]]; then
  TITLE="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('title','$SKILL_SLUG'))" "$INFO_JSON" 2>/dev/null || echo "$SKILL_SLUG")"
fi

echo "== 3/5 extracting frames (every ${FRAME_INTERVAL}s, max ${MAX_FRAMES})"
FRAMES_DIR="$WORKDIR/frames"
mkdir -p "$FRAMES_DIR"
ffmpeg -nostdin -y -loglevel error -i "$VIDEO_PATH" \
  -vf "fps=1/${FRAME_INTERVAL}" -frames:v "$MAX_FRAMES" \
  "$FRAMES_DIR/frame-%03d.jpg"

echo "== 4/5 transcribing audio"
AUDIO_PATH="$WORKDIR/audio.wav"
ffmpeg -nostdin -y -loglevel error -i "$VIDEO_PATH" -ac 1 -ar 16000 -vn "$AUDIO_PATH"

TRANSCRIPT_TXT="$WORKDIR/transcript.txt"
TRANSCRIPT_JSON="$WORKDIR/transcript.json"
python3 - "$AUDIO_PATH" "$TRANSCRIPT_TXT" "$TRANSCRIPT_JSON" "$WHISPER_MODEL" <<'PYEOF'
import json, sys
from faster_whisper import WhisperModel

audio_path, txt_path, json_path, model_size = sys.argv[1:5]
model = WhisperModel(model_size, device="cpu", compute_type="int8")
segments, info = model.transcribe(audio_path, beam_size=5)

lines = []
records = []
for seg in segments:
    text = seg.text.strip()
    lines.append(text)
    records.append({"start": seg.start, "end": seg.end, "text": text})

with open(txt_path, "w") as f:
    f.write(" ".join(lines).strip() + "\n")
with open(json_path, "w") as f:
    json.dump({"language": info.language, "segments": records}, f, indent=2)
PYEOF

echo "== 5/5 writing skill to ${SKILLS_DIR}/${SKILL_SLUG}"
SKILL_DIR="${SKILLS_DIR}/${SKILL_SLUG}"
mkdir -p "$SKILL_DIR/assets/frames"
cp "$FRAMES_DIR"/*.jpg "$SKILL_DIR/assets/frames/" 2>/dev/null || true
cp "$TRANSCRIPT_TXT" "$SKILL_DIR/assets/transcript.txt"
cp "$TRANSCRIPT_JSON" "$SKILL_DIR/assets/transcript.json"
[[ -n "$INFO_JSON" ]] && cp "$INFO_JSON" "$SKILL_DIR/assets/source-metadata.json"

FRAME_COUNT=$(ls "$SKILL_DIR/assets/frames" | wc -l | tr -d ' ')
TRANSCRIPT_PREVIEW=$(head -c 400 "$TRANSCRIPT_TXT")

cat > "$SKILL_DIR/SKILL.md" <<SKILLEOF
---
name: ${SKILL_SLUG}
description: Reference material captured from the video "${TITLE}" (${VIDEO_URL}) — ${FRAME_COUNT} sampled frames plus a full transcript. Use when asked about this video's content, to recall what it showed or said, or to build on it. EDIT THIS DESCRIPTION once you've reviewed the material below so it names the specific topic, not just "a video".
version: 0.1.0
user-invocable: true
---

# ${TITLE}

Source: ${VIDEO_URL}

This skill was generated automatically by \`/video-to-skill\`. It has not been
summarized or curated yet — treat it as raw source material to read before
relying on it, and rewrite this file's description/body once you know what's
actually in here.

## Contents

- \`assets/frames/\` — ${FRAME_COUNT} frames sampled every ${FRAME_INTERVAL}s from the video
- \`assets/transcript.txt\` — plain-text transcript of the audio
- \`assets/transcript.json\` — transcript with per-segment timestamps
$( [[ -n "$INFO_JSON" ]] && echo "- \`assets/source-metadata.json\` — title/duration/uploader metadata from yt-dlp" )

## Transcript preview

> ${TRANSCRIPT_PREVIEW}...

See \`assets/transcript.txt\` for the full text, or \`assets/transcript.json\`
to jump to a specific timestamp and cross-reference the nearest frame in
\`assets/frames/\` (frames are spaced ${FRAME_INTERVAL}s apart, numbered in order).
SKILLEOF

echo "== done"
echo "skill written to: $SKILL_DIR"
echo "frames: $FRAME_COUNT"
echo "transcript chars: $(wc -c < "$TRANSCRIPT_TXT")"
