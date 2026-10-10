"""Builds the hadith and dua lists of assets/data/wamdat.json from the HadeethEnc API.

Rules (enforced here, not by hand):
  - grade is "صحيح" and attribution starts with "متفق عليه" (narrated by both al-Bukhari and Muslim)
  - the Prophet's words are the single «…» quotation in the API text, copied verbatim
  - short enough for a notification, a widget and a video (MAX_CHARS)
Hadiths whose words begin "اللهم" or "رب" become duas; ones mentioning الجمعة go to Friday.
Quranic items (ayahs, Quranic duas and Friday ayahs, verbatim from Tanzil) are kept as they are.

Run:  python3 tool/fetch_hadith.py           (writes assets/data/wamdat.json)
      python3 tool/fetch_hadith.py --check   (fetch and report only)
"""
import hashlib
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

API = 'https://hadeethenc.com/api/v1'
PAGE_URL = 'https://hadeethenc.com/ar/browse/hadith/{}'
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'data' / 'wamdat.json'
MAX_CHARS = 150
MIN_CHARS = 12
MIN_HADITH = 30
MIN_DUA_FROM_API = 3


def get(path, **params):
    url = f'{API}/{path}/?' + urllib.parse.urlencode({'language': 'ar', **params})
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'AlqareeApp-content/1.0 (+https://github.com/khalid-1996/alqreeapp)'})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode('utf-8'))
        except Exception as e:  # network hiccups: back off and retry
            if attempt == 4:
                raise RuntimeError(f'{url}: {e}')
            time.sleep(2 * (attempt + 1))


def bare(s):
    s = unicodedata.normalize('NFD', s)
    return ''.join(ch for ch in s if unicodedata.category(ch) != 'Mn')


def all_ids():
    cats = get('categories/list')
    roots = [c['id'] for c in cats if c.get('parent_id') in (None, '', '0')]
    ids = set()
    for cid in roots:
        page = 1
        while True:
            res = get('hadeeths/list', category_id=cid, page=page, per_page=100)
            ids.update(str(h['id']) for h in res.get('data', []))
            last = int(res.get('meta', {}).get('last_page', 1))
            if page >= last:
                break
            page += 1
            time.sleep(0.2)
    return sorted(ids, key=int)


def fetch_one(hid):
    time.sleep(0.1)
    try:
        return get('hadeeths/one', id=hid)
    except Exception as e:
        print('skip', hid, e, file=sys.stderr)
        return None


QUOTE = re.compile(r'«([^«»]+)»')


def candidate(h):
    """Returns (text, source, id, url) or None if the hadith does not meet every rule."""
    if not h:
        return None
    grade = (h.get('grade') or '').strip()
    attribution = (h.get('attribution') or '').strip().rstrip('.').strip()
    if not grade.startswith('صحيح') or not attribution.startswith('متفق عليه'):
        return None
    full = (h.get('hadeeth') or '').strip()
    quotes = QUOTE.findall(full)
    if len(quotes) != 1:  # several quotations or none: not a single saying, skip
        return None
    words = quotes[0].strip()
    before = bare(full.split('«', 1)[0])
    # The quotation must be attributed to the Prophet ﷺ.
    if not any(k in before for k in ('رسول الله', 'النبي', 'ﷺ', 'صلى الله عليه وسلم')):
        return None
    if not (MIN_CHARS <= len(words) <= MAX_CHARS):
        return None
    hid = str(h['id'])
    return {'text': f'«{words}»', 'source': attribution, 'id': hid, 'url': PAGE_URL.format(hid)}


def spread(items):
    """Stable order that mixes topics (the API lists them grouped)."""
    return sorted(items, key=lambda x: hashlib.sha1(x['id'].encode()).hexdigest())


def main():
    check = '--check' in sys.argv
    ids = all_ids()
    print('hadiths listed:', len(ids))
    with ThreadPoolExecutor(max_workers=4) as pool:
        details = list(pool.map(fetch_one, ids))
    found = [c for c in map(candidate, details) if c]
    print('agreed-upon and short:', len(found))

    hadith, duas, friday = [], [], []
    for c in found:
        b = bare(c['text'].strip('«» '))
        if 'الجمعة' in b:
            friday.append(c)
        elif b.startswith('اللهم') or b.startswith('رب'):
            duas.append(c)
        else:
            hadith.append(c)

    current = json.loads(OUT.read_text())
    is_quran = lambda x: x.get('source', '').startswith('سورة')
    quran_duas = [d for d in current['dua'] if is_quran(d)]
    quran_friday = [f for f in current['friday'] if is_quran(f)]

    hadith = spread(hadith)
    api_duas = spread(duas)
    # Alternate Quran and Sunnah duas.
    merged = []
    for i in range(max(len(quran_duas), len(api_duas))):
        if i < len(api_duas):
            merged.append(api_duas[i])
        if i < len(quran_duas):
            merged.append(quran_duas[i])

    print(f'hadith {len(hadith)}, duas from API {len(api_duas)} (+{len(quran_duas)} Quranic), friday {len(friday)} (+{len(quran_friday)} ayahs)')
    if len(hadith) < MIN_HADITH or len(api_duas) < MIN_DUA_FROM_API:
        sys.exit('too few results: keeping the current file')

    out = {
        'meta': {
            'version': max(3, int(current.get('meta', {}).get('version', 0))),
            'hadith_source': 'HadeethEnc API (hadeethenc.com): grade صحيح, attribution متفق عليه, quoted verbatim',
            'quran_text': current.get('meta', {}).get('quran_text', ''),
            'updated': time.strftime('%Y-%m-%d'),
        },
        'hadith': hadith,
        'dua': merged,
        'ayah': current['ayah'],
        'friday': spread(friday) + quran_friday,
    }
    if check:
        print(json.dumps({k: out[k][:3] for k in ('hadith', 'dua', 'friday')}, ensure_ascii=False, indent=1))
        return
    # Keep the content version stable unless the lists really changed.
    old = {k: current.get(k) for k in ('hadith', 'dua', 'ayah', 'friday')}
    new = {k: out[k] for k in ('hadith', 'dua', 'ayah', 'friday')}
    if old == new:
        print('no change')
        return
    if current.get('meta', {}).get('hadith_source', '').startswith('HadeethEnc'):
        out['meta']['version'] = int(current['meta']['version']) + 1
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + '\n')
    print('written', OUT, 'version', out['meta']['version'])


if __name__ == '__main__':
    main()
