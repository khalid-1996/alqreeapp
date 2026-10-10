"""Daily ومضة video service for the home server (TikTok account).

Every day at RENDER_AT (container local time, set TZ) it renders today's and tomorrow's ومضة
into OUT_DIR/<date>/ (wamda.mp4, wamda.png, wamda.txt, wamda.json) and keeps KEEP_DAYS days.
A small HTTP API lets Hermes (or n8n) fetch the files and ask for a re-render:

  GET /health                       -> {"ok": true}
  GET /today                        -> today's metadata (renders it first if missing)
  GET /day/2026-10-14               -> that day's metadata (renders it first if missing)
  GET /render?date=2026-10-14&force=1
  GET /files/2026-10-14/wamda.mp4   -> the video (also wamda.png, wamda.txt)

Metadata: {date, type, text, source, url, caption, video, poster} with absolute file URLs
built from PUBLIC_BASE (default http://<host>:<port>).

The content is the app's own file (CONTENT_URL), so the video always matches the app.
"""
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HERE = Path(__file__).resolve().parent
OUT = Path(os.environ.get('OUT_DIR', '/out'))
PORT = int(os.environ.get('PORT', '8090'))
RENDER_AT = os.environ.get('RENDER_AT', '05:00')
KEEP_DAYS = int(os.environ.get('KEEP_DAYS', '14'))
CONTENT_URL = os.environ.get(
    'CONTENT_URL', 'https://cdn.jsdelivr.net/gh/khalid-1996/alqreeapp@main/assets/data/wamdat.json')
PUBLIC_BASE = os.environ.get('PUBLIC_BASE', '').rstrip('/')
LOCK = threading.Lock()


def log(*a):
    print(time.strftime('%Y-%m-%d %H:%M:%S'), *a, flush=True)


def render(day, force=False):
    """Renders one day into OUT/<day>/ unless it is already there. Returns its metadata."""
    folder = OUT / day.isoformat()
    meta = folder / 'wamda.json'
    with LOCK:
        if meta.exists() and not force:
            return json.loads(meta.read_text())
        tmp = OUT / f'.{day.isoformat()}.tmp'
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir(parents=True)
        log('render', day)
        res = subprocess.run(
            [sys.executable, str(HERE / 'render.py'), '--out', str(tmp / 'wamda.mp4'),
             '--date', day.isoformat(), '--content', CONTENT_URL],
            capture_output=True, text=True, timeout=900)
        if res.returncode != 0:
            shutil.rmtree(tmp, ignore_errors=True)
            raise RuntimeError(res.stderr.strip()[-800:] or 'render failed')
        info = json.loads(res.stdout.strip().splitlines()[-1])
        info = {
            'date': day.isoformat(),
            'type': info['type'],
            'text': info['text'],
            'source': info['source'],
            'url': info.get('url'),
            'caption': (tmp / 'wamda.txt').read_text(),
        }
        (tmp / 'wamda.json').write_text(json.dumps(info, ensure_ascii=False, indent=1))
        shutil.rmtree(folder, ignore_errors=True)
        tmp.rename(folder)
        return info


def cleanup():
    cutoff = dt.date.today() - dt.timedelta(days=KEEP_DAYS)
    for d in OUT.iterdir():
        try:
            if d.is_dir() and dt.date.fromisoformat(d.name) < cutoff:
                shutil.rmtree(d)
        except ValueError:
            pass


def daily():
    """Renders today and tomorrow at start-up and every day at RENDER_AT."""
    while True:
        today = dt.date.today()
        for day in (today, today + dt.timedelta(days=1)):
            try:
                render(day)
            except Exception as e:
                log('render failed', day, e)
        cleanup()
        h, m = map(int, RENDER_AT.split(':'))
        now = dt.datetime.now()
        nxt = now.replace(hour=h, minute=m, second=0, microsecond=0)
        if nxt <= now:
            nxt += dt.timedelta(days=1)
        time.sleep((nxt - now).total_seconds())


class Api(BaseHTTPRequestHandler):
    def base(self):
        return PUBLIC_BASE or f'http://{self.headers.get("Host", f"localhost:{PORT}")}'

    def send_json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def with_links(self, info):
        d = info['date']
        return {**info,
                'video': f'{self.base()}/files/{d}/wamda.mp4',
                'poster': f'{self.base()}/files/{d}/wamda.png'}

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        parts = [p for p in u.path.split('/') if p]
        try:
            if parts == ['health']:
                return self.send_json({'ok': True})
            if parts in (['today'], ['tomorrow']) or (len(parts) == 2 and parts[0] == 'day') or parts == ['render']:
                if parts == ['today']:
                    day = dt.date.today()
                elif parts == ['tomorrow']:
                    day = dt.date.today() + dt.timedelta(days=1)
                elif parts[0] == 'day':
                    day = dt.date.fromisoformat(parts[1])
                else:
                    day = dt.date.fromisoformat(q.get('date', [dt.date.today().isoformat()])[0])
                force = parts == ['render'] and q.get('force', ['0'])[0] == '1'
                return self.send_json(self.with_links(render(day, force)))
            if len(parts) == 3 and parts[0] == 'files' and parts[2] in ('wamda.mp4', 'wamda.png', 'wamda.txt'):
                dt.date.fromisoformat(parts[1])  # only date folders
                f = OUT / parts[1] / parts[2]
                if not f.exists():
                    return self.send_json({'error': 'not rendered'}, 404)
                ctype = {'mp4': 'video/mp4', 'png': 'image/png', 'txt': 'text/plain; charset=utf-8'}[f.suffix[1:]]
                self.send_response(200)
                self.send_header('Content-Type', ctype)
                self.send_header('Content-Length', str(f.stat().st_size))
                self.end_headers()
                with f.open('rb') as fh:
                    shutil.copyfileobj(fh, self.wfile)
                return
            self.send_json({'error': 'not found'}, 404)
        except ValueError as e:
            self.send_json({'error': f'bad date: {e}'}, 400)
        except Exception as e:
            log('error', e)
            self.send_json({'error': str(e)}, 500)

    def log_message(self, fmt, *args):
        log(self.address_string(), fmt % args)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    threading.Thread(target=daily, daemon=True).start()
    log(f'listening on :{PORT}, rendering daily at {RENDER_AT} ({os.environ.get("TZ", "UTC")})')
    ThreadingHTTPServer(('0.0.0.0', PORT), Api).serve_forever()
