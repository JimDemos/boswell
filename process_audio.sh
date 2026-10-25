#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <audio_file> [meeting_title] [attendees]"
  echo "  audio_file:    path to .m4a/.mp3/.wav/.ogg/etc"
  echo "  meeting_title: short label for the report filename"
  echo "  attendees:     comma-separated names (optional)"
  exit 1
fi

AUDIO="$1"
TITLE="${2:-meeting}"
ATTENDEES="${3:-}"

if [ ! -f "$AUDIO" ]; then
  echo "Audio file not found: $AUDIO" >&2
  exit 1
fi

cd "$(dirname "$0")"

DATE=$(date +%Y-%m-%d)
SAFE_TITLE=$(echo "$TITLE" | tr ' /' '--' | tr -cd 'A-Za-z0-9-')
TRANSCRIPT="field-reports/transcript-${DATE}-${SAFE_TITLE}.txt"

echo "[1/2] Transcribing $AUDIO with Whisper medium.en on GPU..."
python3 - <<PYEOF
from faster_whisper import WhisperModel
import sys
model = WhisperModel('medium.en', device='cuda', compute_type='float16')
segments, info = model.transcribe('$AUDIO', beam_size=5, vad_filter=True)
with open('$TRANSCRIPT', 'w') as f:
    for s in segments:
        f.write(f'[{s.start:7.1f}s] {s.text.strip()}\n')
print(f'  Transcribed {info.duration:.1f}s of audio -> $TRANSCRIPT', file=sys.stderr)
PYEOF

echo "[2/2] Generating field report..."
if [ -n "$ATTENDEES" ]; then
  python3 -m boswell.report --transcript "$TRANSCRIPT" --title "$TITLE" --attendees "$ATTENDEES"
else
  python3 -m boswell.report --transcript "$TRANSCRIPT" --title "$TITLE"
fi

echo
echo "Done. Outputs in field-reports/"
ls -lt field-reports/ | head -5
