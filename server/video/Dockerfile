# Daily ومضة video service. Build from the repo root:
#   docker build -f server/video/Dockerfile -t alqaree-video .
FROM mcr.microsoft.com/playwright/python:v1.47.0-jammy

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg tzdata \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY assets/icon/logo_white.png assets/icon/logo_white.png
COPY server/video/render.py server/video/template.html server/video/server.py server/video/
# Amiri and Tajawal from npm (@fontsource), baked into the image.
RUN python3 -c "import sys; sys.path.insert(0, 'server/video'); import render; render.get_fonts()"

ENV TZ=Asia/Dubai \
    OUT_DIR=/out \
    PORT=8090 \
    RENDER_AT=05:00 \
    KEEP_DAYS=14 \
    PYTHONUNBUFFERED=1
VOLUME /out
EXPOSE 8090
HEALTHCHECK --interval=5m --timeout=10s CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8090/health')"
CMD ["python3", "server/video/server.py"]
