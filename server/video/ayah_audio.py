"""Real recitation for a Quran ومضة: downloads the reciter's audio of the verse(s) from Quran.com
and, when the ومضة shows only part of a verse, cuts the audio to exactly those words using
Quran.com's word timings. Never synthesizes Quran audio.

  python3 ayah_audio.py --source "سورة الرعد · 28" --text "﴿أَلَا بِذِكْرِ ٱللَّهِ تَطْمَئِنُّ ٱلْقُلُوبُ﴾" --out ayah.m4a
  python3 ayah_audio.py --list-reciters
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
import unicodedata
import urllib.request
from pathlib import Path

API = 'https://api.quran.com/api/v4'
AUDIO = 'https://verses.quran.com/'
UA = {'User-Agent': 'AlqareeApp/1.0 (+https://github.com/khalid-1996/alqreeapp)'}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
        return r.read()


def letters(s):
    """Arabic letters only, with the spelling differences of the Uthmani script folded."""
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    s = re.sub('[أإآٱا]', 'ا', s).replace('ى', 'ي').replace('ة', 'ه').replace('ؤ', 'و').replace('ئ', 'ي')
    s = s.replace('ٰ', '').replace('ـ', '')
    return re.sub(r'[^ء-ي]', '', s)


def surah_number(name):
    name = letters(name.replace('سورة', ''))
    for ch in json.loads(get(f'{API}/chapters?language=ar'))['chapters']:
        if letters(ch['name_arabic']) == name:
            return ch['id']
    raise SystemExit(f'surah not found: {name}')


def verse_words(key):
    v = json.loads(get(f'{API}/verses/by_key/{key}?words=true&word_fields=text_uthmani'))['verse']
    return [w['text_uthmani'] for w in v['words'] if w.get('char_type_name') == 'word']


def recitation(reciter, key):
    j = json.loads(get(f'{API}/recitations/{reciter}/by_ayah/{key}'))
    f = j['audio_files'][0]
    url = f['url'] if f['url'].startswith('http') else AUDIO + f['url'].lstrip('/')
    return url, f.get('segments') or []


def word_span(shown, words):
    """Index range [i, j) of the shown words inside the verse, or None for the whole verse."""
    target = letters(shown)
    ws = [letters(w) for w in words]
    if target == ''.join(ws):
        return None
    for i in range(len(ws)):
        acc = ''
        for j in range(i, len(ws)):
            acc += ws[j]
            if acc == target:
                return i, j + 1
            if not target.startswith(acc):
                break
    raise SystemExit('the shown text is not a contiguous part of the verse')


def segment_times(segments, i, j):
    """Start and end (ms) of words i..j-1 (0-based). Segments are [word_position(1-based), start, end]
    or [index, word_position, start, end] depending on the reciter."""
    by_word = {}
    for s in segments:
        pos, start, end = (s[0], s[1], s[2]) if len(s) == 3 else (s[1], s[2], s[3])
        by_word[int(pos)] = (int(start), int(end))
    if (i + 1) not in by_word or j not in by_word:
        raise SystemExit(f'no word timings for words {i + 1}..{j}')
    return by_word[i + 1][0], by_word[j][1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source')
    ap.add_argument('--text')
    ap.add_argument('--reciter', type=int, default=7, help='Quran.com recitation id (7 = Mishari Alafasy)')
    ap.add_argument('--out', default='ayah.m4a')
    ap.add_argument('--list-reciters', action='store_true')
    a = ap.parse_args()
    if a.list_reciters:
        for r in json.loads(get(f'{API}/resources/recitations?language=ar'))['recitations']:
            print(r['id'], r.get('reciter_name'), r.get('style') or '', '|', (r.get('translated_name') or {}).get('name', ''))
        return

    m = re.match(r'سورة (.+?) · (\d+)(?:[–-](\d+))?$', a.source.strip())
    if not m:
        raise SystemExit(f'unexpected source: {a.source}')
    s = surah_number(m.group(1))
    first, last = int(m.group(2)), int(m.group(3) or m.group(2))
    shown = a.text.strip().strip('﴿﴾')

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        parts = []
        for n, ayah in enumerate(range(first, last + 1)):
            key = f'{s}:{ayah}'
            url, segs = recitation(a.reciter, key)
            src = tmp / f'{n}.mp3'
            src.write_bytes(get(url))
            cut = ['-i', str(src)]
            if first == last:
                span = word_span(shown, verse_words(key))
                if span:
                    start, end = segment_times(segs, *span)
                    cut = ['-ss', f'{max(0, start - 120) / 1000:.3f}', '-to', f'{(end + 250) / 1000:.3f}', '-i', str(src)]
                    print(f'{key}: words {span[0] + 1}..{span[1]} of {len(verse_words(key))}, {start}-{end} ms', file=sys.stderr)
                else:
                    print(f'{key}: whole verse', file=sys.stderr)
            else:
                print(f'{key}: whole verse (range)', file=sys.stderr)
            wav = tmp / f'{n}.wav'
            subprocess.run(['ffmpeg', '-v', 'error', '-y', *cut, '-ar', '48000', '-ac', '2', str(wav)], check=True)
            parts.append(wav)
        lst = tmp / 'list.txt'
        lst.write_text(''.join(f"file '{p}'\n" for p in parts))
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(lst),
                        '-af', 'afade=t=in:d=0.08,loudnorm=I=-14:TP=-1.5:LRA=11,adelay=500|500,apad=pad_dur=1.0',
                        '-c:a', 'aac', '-b:a', '160k', a.out], check=True)
    print(a.out)


if __name__ == '__main__':
    main()
