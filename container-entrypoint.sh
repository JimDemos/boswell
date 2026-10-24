#!/bin/sh
# Boswell container entrypoint — CPU-safe, portable.
# (process_audio.sh pins device=cuda; `python -m boswell` is live capture.
#  This exposes a GPU-free file-processing surface for the portable image.)
set -e
cmd="${1:-help}"
case "$cmd" in
  transcribe)
    shift
    audio="$1"
    [ -n "$audio" ] || { echo "usage: transcribe <audiofile>" >&2; exit 2; }
    [ -f "$audio" ] || { echo "not found: $audio" >&2; exit 2; }
    model="${BOSWELL_MODEL:-small.en}"
    out="/out/$(basename "${audio%.*}").txt"
    python - "$audio" "$model" "$out" <<'PY'
import sys
from faster_whisper import WhisperModel
audio, model_name, out = sys.argv[1], sys.argv[2], sys.argv[3]
m = WhisperModel(model_name, device="cpu", compute_type="int8", download_root="/opt/models")
segments, info = m.transcribe(audio, beam_size=5, vad_filter=True)
with open(out, "w") as f:
    for s in segments:
        f.write(f"[{s.start:7.1f}s] {s.text.strip()}\n")
print(f"[boswell] transcribed {info.duration:.1f}s of audio -> {out}", file=sys.stderr)
PY
    ;;
  report)
    shift
    exec python -m boswell.report --output-dir /out "$@"
    ;;
  help|--help|-h|"")
    echo "boswell (portable CPU image)"
    echo "  transcribe <audiofile>          audio -> /out/<name>.txt   (no API key, no GPU)"
    echo "  report --transcript <f> [opts]  field report -> /out       (needs LLM key, or --dry-run)"
    echo "  <anything else>                 passed to: python -m boswell"
    ;;
  *)
    exec python -m boswell "$@"
    ;;
esac
