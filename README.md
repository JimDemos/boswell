<p align="center">
  <img src="docs/boswell-quill.jpg" alt="Boswell" width="170">
</p>

<h1 align="center">Boswell</h1>

<p align="center">
  <strong>Meeting transcription that never leaves your machine.</strong><br>
  No cloud touches your audio. Your hardware, your model, your transcript.
</p>

<p align="center"><em>Named after James Boswell, who sat in the room and wrote down what was said.</em></p>

<p align="center">
  <img src="https://img.shields.io/badge/license-Apache_2.0-informational" alt="license">
  <img src="https://img.shields.io/badge/python-3.10+-informational" alt="python">
  <img src="https://img.shields.io/badge/audio-PipeWire_/_PulseAudio-informational" alt="audio">
</p>

---

Boswell captures audio playing on your Linux desktop and transcribes it **locally** with [faster-whisper](https://github.com/SYSTRAN/faster-whisper). The transcript is a text file on your disk. Optionally, a local LLM turns it into a field report. No subscription, no account, no one else's server in the middle.

**See it** — a live transcript streams as the meeting happens:

```
--- session 2026-03-11T15:02:00Z ---
[00:02:14] ...so if we move the launch to Q3 we lose the trade-show window entirely.
[00:02:29] Agreed. Let's lock Q2 and cut the analytics dashboard from v1 instead.
```

...and the optional report turns that into:

```
## Decisions
- Launch stays in Q2; analytics dashboard deferred to v1.1.
## Action items
- Re-scope v1 without the dashboard before Friday.
```

## Start in three commands

```bash
git clone https://github.com/JimDemos/boswell.git && cd boswell
pip install -r requirements.txt
./boswellctl start      # ...hold your meeting... then: ./boswellctl stop
```

Your transcript is waiting in `transcript.log`. Runs on **CPU by default** (add `--gpu` on an NVIDIA box). Nothing else required.

> **One thing to know up front:** Boswell captures what your computer **plays** — the remote participants you hear. It does **not** capture your microphone by default, so your own voice won't be in the transcript unless you mix it in ([recipe below](#capturing-both-sides)). And since it's a meeting recorder: make sure everyone in the room is okay with being recorded.

## What it does

- **Capture** — real-time speech-to-text from any desktop audio source. Timestamped transcript streams to a file as the meeting happens.
- **Summarize** — after the meeting, generate a structured field report (summary, decisions, action items, quotes) via any OpenAI-compatible LLM. Point it at a local Ollama and it never leaves your machine.
- **Advise** *(experimental)* — tail the transcript live and surface notes via desktop notification during the meeting.

## Why local

Otter, Fireflies, and built-in meeting transcription all work — and all send your audio to someone else's servers, process it with someone else's model, and keep the raw transcript on someone else's infrastructure. Boswell inverts that: Whisper runs on your CPU or GPU, the summarizer is whatever LLM you choose (or none), and the transcript is a file you own. It runs on an air-gapped network. **One honest caveat:** audio never leaves your machine, but Whisper downloads its model once (from Hugging Face), and if you opt into a *cloud* LLM for summaries, that text goes where you point it. Use a local model and nothing leaves at all.

## Three ways to run it

### 1. Native — start and stop a meeting

```bash
./boswellctl start      # begin capturing desktop audio; returns immediately
./boswellctl status     # running / stopped
./boswellctl stop       # end capture — transcript saved
```

CPU by default; `--gpu` only on NVIDIA. Choose a model with `--model` (`small.en` is responsive on a laptop, `medium.en` trades speed for accuracy).

### 2. One-click launcher

```bash
sh desktop/install.sh      # adds a Start/Stop icon to your app grid
```

Click to start, click again to stop — it just wraps `boswellctl`. Remove it with `rm ~/.local/share/applications/boswell.desktop`.

### 3. Container — portable, no install

A portable image (UBI + faster-whisper, model baked in). CPU-only, no GPU or CUDA needed.

```bash
# transcribe a recording you already have
podman run --rm -v "$PWD:/work:Z" -v "$PWD/out:/out:Z" \
  ghcr.io/jimdemos/boswell transcribe /work/meeting.m4a

# live capture off the desktop (Linux/PipeWire host)
podman run --rm --name boswell-live --security-opt label=disable \
  -v "$XDG_RUNTIME_DIR/pulse/native:/run/pulse/native" \
  -e PULSE_SERVER=unix:/run/pulse/native \
  -v "$PWD/out:/out" \
  --entrypoint python ghcr.io/jimdemos/boswell \
  -m boswell.capture --source "$(pactl get-default-sink).monitor" --file /out/live.txt --skip-checks
```

`--security-opt label=disable` is required on SELinux hosts (Fedora/RHEL) for the container to reach the host audio socket.

## Capturing both sides

By default you get the remote audio only. To record **your microphone too**, mix both into a null sink and capture that:

```bash
pactl load-module module-null-sink sink_name=boswell_mix
pactl load-module module-loopback source="$(pactl get-default-sink).monitor" sink=boswell_mix   # remote
pactl load-module module-loopback source=@DEFAULT_SOURCE@ sink=boswell_mix                       # your mic
./boswellctl start --source boswell_mix.monitor
```

## Requirements

- **Linux** with PipeWire (default on Fedora 34+, Ubuntu 22.10+, RHEL 9+)
- **Python 3.10+**, plus `pactl`/`parec` (shipped with most PipeWire setups)
- **Ollama** or any OpenAI-compatible endpoint — only for summaries. Capture needs none.

Whisper models range from `base.en` (~150 MB, fast) to `large-v3` (~3 GB, most accurate). The default CPU path (int8) keeps up with conversational speech on a modern machine; for live capture on a laptop prefer `small.en`/`medium.en` and save `large-v3` for GPU or offline processing. Non-English speakers: drop the `.en` suffix (e.g. `--model medium`).

## Modes, in detail

```bash
# Capture only (no LLM)
python -m boswell.capture                 # auto-detect source
python -m boswell.capture --list-sources
python -m boswell.capture --model large-v3

# Combined: capture + summarize (+ optional live advisory)
python -m boswell                         # Ctrl+C ends and writes a report
python -m boswell --attendees "Alice,Bob"
python -m boswell --no-advisory

# Report from an existing transcript
python -m boswell.report --transcript path/to/transcript.log --title "Q3 Planning"
```

## Configuration

Copy `config.example.yaml` to `config.yaml`:

```yaml
user:   { name: "Your Name", role: "Your Role", org: "Your Org" }
model:  { endpoint: "http://localhost:11434/v1", name: "granite3.2:8b", key_file: "" }
```

`user` personalizes the report and advisory prompts. `model` points at any OpenAI-compatible endpoint — Ollama, vLLM, LiteLLM, or a cloud provider, your choice.

## Troubleshooting

- **No transcript / silence:** confirm audio is actually playing, then `python -m boswell.capture --list-sources` to check the source. Boswell follows the default sink; if that's wrong, pass `--source <name>`.
- **First run is slow:** the Whisper model downloads once, then it's cached.
- **GPU flag errors:** `--gpu` is NVIDIA/CUDA only. On Intel/AMD, omit it — CPU is the default.
- **Container can't reach audio:** on Fedora/RHEL you need `--security-opt label=disable` (SELinux) for the pulse socket mount.

## Contributing

Issues and PRs welcome. Boswell is a small, readable codebase (`boswell/` is ~1,200 lines of Python); start there.

## Origins

Boswell began inside the [Zoe](https://github.com/zoe-network) project and is now independent. The lineage stays in the git history.

## License

Apache 2.0.
