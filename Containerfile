# Boswell — portable CPU image (faster-whisper int8, no GPU, no CUDA).
# UBI base: freely redistributable, RHEL-aligned, runs non-root (uid 1001).
FROM registry.access.redhat.com/ubi9/python-311:latest

ARG BOSWELL_MODEL=small.en
ENV BOSWELL_MODEL=${BOSWELL_MODEL} \
    XDG_CACHE_HOME=/opt/models \
    HF_HOME=/opt/models \
    PIP_NO_CACHE_DIR=1

USER root
WORKDIR /app

# parec (pulseaudio-utils) is needed for LIVE capture off a Pulse/PipeWire source.
# ffmpeg for file decoding comes bundled in the PyAV wheel, so only parec is a system dep.
RUN dnf install -y pulseaudio-utils && dnf clean all

# Python deps
COPY requirements.txt .
RUN pip install -r requirements.txt

# App + CPU-safe entrypoint
COPY . .
RUN install -m 0755 container-entrypoint.sh /usr/local/bin/boswell-entry \
 && mkdir -p /opt/models /out

# Pre-bake the default model so the image transcribes offline out of the box
RUN python -c "from faster_whisper import WhisperModel; WhisperModel('${BOSWELL_MODEL}', device='cpu', compute_type='int8', download_root='/opt/models')" \
 && chown -R 1001:0 /opt/models /out && chmod -R g=u /opt/models /out

USER 1001
VOLUME ["/out"]
ENTRYPOINT ["/usr/local/bin/boswell-entry"]
CMD ["help"]
