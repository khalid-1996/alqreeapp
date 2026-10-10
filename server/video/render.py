"""Renders today's ومضة as a vertical 1080x1920 MP4 (no audio), in the app's design.

It reads the same content file as the app and uses the same day formula, so the video,
the app, its widgets and its notifications always show the same ومضة.

Usage:
  python3 render.py --out wamda.mp4                 # today
  python3 render.py --out wamda.mp4 --date 2026-10-10
  python3 render.py --out wamda.mp4 --content https://cdn.jsdelivr.net/gh/khalid-1996/alqreeapp@main/assets/data/wamdat.json

Needs: playwright (pip install playwright && playwright install chromium), ffmpeg,
and the fonts folder (python3 render.py --get-fonts downloads Amiri and Tajawal once).
"""
import argparse
import datetime as dt
import io
import json
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
FONTS = HERE / 'fonts'
LOGO = REPO / 'assets' / 'icon' / 'logo_white.png'
FPS = 30
DURATION = 8.0
TYPE_LABEL = {'hadith': 'حديث', 'dua': 'دعاء', 'ayah': 'آية'}


def get_fonts():
    FONTS.mkdir(exist_ok=True)
    for pkg in ('amiri', 'tajawal'):
        meta = json.load(urllib.request.urlopen(f'https://registry.npmjs.org/@fontsource/{pkg}'))
        tarball = meta['versions'][meta['dist-tags']['latest']]['dist']['tarball']
        with tarfile.open(fileobj=io.BytesIO(urllib.request.urlopen(tarball).read())) as t:
            for m in t.getmembers():
                name = Path(m.name).name
                if name.startswith(f'{pkg}-arabic-') and name.endswith('-normal.woff2'):
                    (FONTS / name).write_bytes(t.extractfile(m).read())
    print('fonts in', FONTS)


def load_content(src):
    if src.startswith('http'):
        return json.load(urllib.request.urlopen(src))
    return json.loads(Path(src).read_text())


def wamda_for(content, day):
    """Same formula as LocalContent.wamdaFor in the app."""
    i = (day - dt.date(1970, 1, 1)).days
    kind = ['hadith', 'dua', 'ayah'][i % 3]
    items = content[kind]
    return kind, items[(i // 3) % len(items)]


def font_size(text):
    n = len(text)
    return 96 if n <= 50 else 84 if n <= 90 else 72 if n <= 140 else 60 if n <= 200 else 52 if n <= 250 else 46


def render(kind, item, out):
    from playwright.sync_api import sync_playwright

    html = (HERE / 'template.html').read_text()
    html = (html.replace('TEXT', item['text']).replace('SOURCE', item['source'])
            .replace('TYPE', TYPE_LABEL[kind]).replace('LOGO', LOGO.as_uri())
            .replace('FONTSIZE', str(font_size(item['text']))).replace('FONTS', FONTS.as_uri()))
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        page_file = tmp / 'page.html'
        page_file.write_text(html)
        with sync_playwright() as p:
            browser = p.chromium.launch()
            page = browser.new_page(viewport={'width': 1080, 'height': 1920})
            page.goto(page_file.as_uri())
            page.evaluate('document.fonts.ready')
            page.evaluate(f'window.DURATION = {DURATION}')
            for i in range(int(FPS * DURATION)):
                page.evaluate(f'render({i / FPS})')
                page.screenshot(path=str(tmp / f'{i:04d}.png'))
            browser.close()
        subprocess.run([
            'ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', str(tmp / '%04d.png'),
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'slow', '-crf', '18',
            '-movflags', '+faststart', str(out),
        ], check=True)
        shutil.copy(tmp / f'{int(FPS * 4.6):04d}.png', Path(out).with_suffix('.png'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='wamda.mp4')
    ap.add_argument('--date', help='YYYY-MM-DD, default today')
    ap.add_argument('--content', default=str(REPO / 'assets' / 'data' / 'wamdat.json'))
    ap.add_argument('--get-fonts', action='store_true')
    a = ap.parse_args()
    if a.get_fonts or not FONTS.exists():
        get_fonts()
    day = dt.date.fromisoformat(a.date) if a.date else dt.date.today()
    kind, item = wamda_for(load_content(a.content), day)
    render(kind, item, a.out)
    # Caption for the post, with the source link when there is one.
    caption = f"{item['text']}\n{item['source']}\n\n#ومضات_اليوم #القارئ"
    Path(a.out).with_suffix('.txt').write_text(caption + ('\n' + item['url'] if item.get('url') else ''))
    print(json.dumps({'date': str(day), 'type': kind, **item, 'video': a.out}, ensure_ascii=False))


if __name__ == '__main__':
    main()
