"""Builds the hadith and dua lists of assets/data/wamdat.json from the HadeethEnc API.

Rules (enforced here, not by hand):
  - grade is "صحيح" and attribution starts with "متفق عليه" (narrated by both al-Bukhari and Muslim)
  - the Prophet's own words: the single «…» quotation, introduced right before by
    "قال رسول الله ﷺ" / "النبي ﷺ يقول" (not a Companion's words), copied verbatim
  - stands on its own: not an answer to a question, from reminder categories
    (virtues, character, manners, heart-softeners, remembrance, prayer, charity, fasting, Quran),
    never from rulings that need context (menstruation, penalties, inheritance, war, dreams…)
  - shown in full (narrator, context and the saying), checked against Bukhari's wording
  - short enough for a notification, a widget and a video (MIN_CHARS..MAX_CHARS)
  - found in Sahih al-Bukhari with the same wording; the source shows its Bukhari number
    (matched against the full Arabic text of Sahih al-Bukhari, fawazahmed0/hadith-api)
Duas come only from the "supplications" and adhkar categories; Friday from the Friday categories.
Quranic items (ayahs, Quranic duas and Friday ayahs, verbatim from Tanzil) are kept as they are.

Run:  python3 tool/fetch_hadith.py           (writes assets/data/wamdat.json)
      python3 tool/fetch_hadith.py --check   (fetch and report only)
"""
import hashlib
from collections import Counter
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
MIN_CHARS = 25
MIN_HADITH = 30
MIN_DUA_FROM_API = 0  # Quranic duas always cover this list
MAX_DUA_CHARS = 220
BUKHARI_URL = 'https://raw.githubusercontent.com/fawazahmed0/hadith-api/1/editions/ara-bukhari.min.json'
BUKHARI_MIN_MATCH = 0.6  # share of the hadith's word triples found in one Bukhari hadith


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


def tokens(s):
    s = re.sub('[أإآٱ]', 'ا', bare(s)).replace('ى', 'ي').replace('ة', 'ه').replace('ؤ', 'و').replace('ئ', 'ي')
    return re.sub(r'[^\u0621-\u064A ]', ' ', s).split()


BUKHARI = {}  # word triple -> Bukhari hadith numbers
BUKHARI_GRAMS = {}  # Bukhari hadith number -> its word triples
MAX_FULL_CHARS = 300  # the whole narration as shown: narrator, context and the Prophet's words
BUKHARI_MIN_FULL_MATCH = 0.5  # the narration around the saying may differ a little from Bukhari's


def load_bukhari():
    req = urllib.request.Request(BUKHARI_URL, headers={'User-Agent': 'AlqareeApp-content/1.0'})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read().decode('utf-8'))
    for h in data['hadiths']:
        w = tokens(h["text"])
        grams = {tuple(w[i:i + 3]) for i in range(len(w) - 2)}
        BUKHARI_GRAMS[int(h['hadithnumber'])] = grams
        for g in grams:
            BUKHARI.setdefault(g, set()).add(int(h['hadithnumber']))
    print('Sahih al-Bukhari hadiths:', len(data['hadiths']))


def bukhari_number(text):
    """The Bukhari hadith that holds this wording, or None."""
    w = tokens(text)
    grams = [tuple(w[i:i + 3]) for i in range(len(w) - 2)]
    hits = Counter(n for g in grams for n in BUKHARI.get(g, ()))
    if not grams or not hits:
        return None
    n, k = min(hits.items(), key=lambda x: (-x[1], x[0]))
    return n if k / len(grams) >= BUKHARI_MIN_MATCH else None


def share_in(text, number):
    """Share of the text's word triples found in that Bukhari hadith."""
    w = tokens(text)
    grams = [tuple(w[i:i + 3]) for i in range(len(w) - 2)]
    have = BUKHARI_GRAMS.get(number, set())
    return sum(g in have for g in grams) / len(grams) if grams else 0


PARENT = {}  # category id -> parent id, filled by all_ids()


def all_ids():
    cats = get('categories/list')
    for c in cats:
        try:
            PARENT[int(c['id'])] = int(c['parent_id']) if c.get('parent_id') not in (None, '', '0') else None
        except (TypeError, ValueError):
            pass
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

# HadeethEnc category ids (GET /categories/list/?language=ar).
REMINDER = {
    12, 39, 40,                                         # فضائل القرآن
    92, 94, 95,                                         # زيادة الإيمان، شعب الإيمان، الإحسان
    265, 270, 271, 272, 273, 274, 277, 278, 279, 280, 281,  # الفضائل
    266, 282, 283,                                      # الأخلاق الحميدة والذميمة
    267, 284, 286, 287, 291, 295, 297,                  # الآداب الشرعية
    269, 314, 315, 316, 317, 318, 319, 320, 321, 322, 324,  # الرقائق والمواعظ
    300, 302, 312,                                      # فوائد الذكر، الأذكار المطلقة، أسباب الإجابة
    338, 340, 341,                                      # محاسن الإسلام، حقوق الإنسان والحيوان
    441, 457, 469, 482, 501, 511, 513,                  # فضل الوضوء والصلاة والجماعة والتطوع والزكاة والصدقة والصيام
}
DUA = {268, 301, 302, 307, 313}  # فقه الأدعية والأذكار وفروعه                              # أذكار الصباح والمساء، المطلقة، الشدة، الأدعية المأثورة
FRIDAY = {472, 477, 478, 480}                           # صلاة الجمعة وفضل يومها وأحكامها
NEVER = {                                               # need context or are not for a public daily feed
    123, 127, 128, 139, 191, 192, 195, 196, 197, 198, 199, 205, 219, 220, 224, 225, 226, 227, 228, 230,
    275, 276, 294, 403, 440,
}
PROPHET = ('رسول الله', 'النبي', 'ﷺ', 'صلى الله عليه وسلم')
SAYS = ('قال', 'يقول', 'مرفوعا', 'مرفوعًا')
REPLY_STARTS = ('لا،', 'لا ', 'نعم', 'بلى', 'بل ')

# Editorial review (2026-10-10): authentic and agreed upon, but not for a daily feed read
# without its explanation. Each id is still on HadeethEnc; it just isn't posted.
EXCLUDE = {
    # needs the story around it (who is addressed, what happened)
    3728, 5734, 3688, 6178, 65062, 66096, 65355, 4932, 65703, 3014, 11206, 65711, 65753, 5142,
    # a supplication for named people
    3773, 5469,
    # a ruling or a detail that needs a scholar's explanation
    66111, 6141, 5442, 58112, 2986, 66278, 66277,
    # easily misread on social media without the commentary
    5830, 3184, 65998,
}


def categories(h):
    """The hadith's categories and all their parent sections (the API lists only the most specific one)."""
    out = set()
    for c in h.get('categories') or []:
        cid = c.get('id') if isinstance(c, dict) else c
        try:
            cid = int(cid)
        except (TypeError, ValueError):
            continue
        while cid is not None and cid not in out:
            out.add(cid)
            cid = PARENT.get(cid)
    return out


REJECTED = Counter()


def reject(reason):
    REJECTED[reason] += 1
    return None


def candidate(h):
    """Returns (kind, item) with kind in hadith/dua/friday, or None if any rule fails."""
    if not h:
        return reject('fetch failed')
    if int(h.get('id', 0)) in EXCLUDE:
        return reject('editorial review')
    grade = (h.get('grade') or '').strip()
    attribution = (h.get('attribution') or '').strip().rstrip('.').strip()
    if not grade.startswith('صحيح') or not attribution.startswith('متفق عليه'):
        return reject('not agreed upon')
    cats = categories(h)
    if cats & NEVER:
        return reject('excluded category')
    if cats & FRIDAY:
        kind = 'friday'
    elif cats & DUA:
        kind = 'dua'
    elif cats & REMINDER:
        kind = 'hadith'
    else:
        return reject('not a reminder category')

    full = (h.get('hadeeth') or '').strip()
    quotes = QUOTE.findall(full)
    if len(quotes) != 1:  # several quotations or none: not a single saying
        return reject('not one quotation')
    words = quotes[0].strip()
    before = bare(full.split('«', 1)[0]).strip()
    tail = before[-60:]
    # The Prophet ﷺ is the speaker: named and introduced right before the quotation.
    if not any(p in tail for p in PROPHET) or not any(v in tail for v in SAYS):
        return reject('speaker not the Prophet')
    # An answer to a question does not stand on its own.
    if '؟' in before or any(bare(words).startswith(r) for r in REPLY_STARTS):
        return reject('a reply')
    # A question or a sentence that continues an earlier one (فـ / وـ) needs its context.
    if '؟' in words or bare(words)[:1] in ('ف', 'و'):
        return reject('needs context')
    limit = MAX_DUA_CHARS if kind == 'dua' else MAX_CHARS
    if not (MIN_CHARS <= len(words) <= limit):
        return reject('length')
    if kind == 'dua' and not bare(words).startswith(('اللهم', 'رب', 'يا ')):
        kind = 'hadith'  # e.g. the virtue of a dhikr: a reminder, not a supplication
    number = bukhari_number(words)
    if number is None:
        return reject('not in Bukhari with this wording')
    # Shown in full: the narrator, the context and the Prophet's words.
    text = re.sub(r'\s+', ' ', full).strip()
    if len(text) > MAX_FULL_CHARS:
        return reject('full narration too long')
    if share_in(text, number) < BUKHARI_MIN_FULL_MATCH:
        return reject('full narration not in Bukhari wording')
    hid = str(h['id'])
    return kind, {'text': text, 'quote': f'«{words}»', 'source': f'صحيح البخاري {number}', 'bukhari': number,
                  'id': hid, 'url': PAGE_URL.format(hid)}


def letters(s):
    return re.sub(r'[^\u0621-\u064A]', '', bare(s))


def dedupe(items):
    """Drops near-duplicates (the same saying in several narrations); keeps the shortest."""
    from difflib import SequenceMatcher
    kept = []
    for it in sorted(items, key=lambda x: (len(x['text']), int(x['id']))):
        a = letters(it['text'])
        if any(SequenceMatcher(None, a, letters(k['text'])).ratio() > 0.7 for k in kept):
            REJECTED['near duplicate'] += 1
            continue
        kept.append(it)
    return kept


def spread(items):
    """Stable order that mixes topics (the API lists them grouped)."""
    return sorted(items, key=lambda x: hashlib.sha1(x['id'].encode()).hexdigest())


def main():
    check = '--check' in sys.argv
    load_bukhari()
    ids = all_ids()
    print('hadiths listed:', len(ids))
    with ThreadPoolExecutor(max_workers=4) as pool:
        details = list(pool.map(fetch_one, ids))
    sample = next((d for d in details if d), {})
    print(f"::notice title=categories field::{json.dumps(sample.get('categories'), ensure_ascii=False)[:200]}")
    found = [c for c in map(candidate, details) if c]
    print('passed every rule:', len(found))
    print('::notice title=rejected::' + ', '.join(f'{k}: {v}' for k, v in REJECTED.most_common()))
    hadith = [item for kind, item in found if kind == 'hadith']
    duas = [item for kind, item in found if kind == 'dua']
    friday = [item for kind, item in found if kind == 'friday']

    current = json.loads(OUT.read_text())
    is_quran = lambda x: x.get('source', '').startswith('سورة')
    quran_duas = [d for d in current['dua'] if is_quran(d)]
    quran_friday = [f for f in current['friday'] if is_quran(f)]

    hadith = spread(dedupe(hadith))
    api_duas = spread(dedupe(duas))
    friday = dedupe(friday)
    # Alternate Quran and Sunnah duas.
    merged = []
    for i in range(max(len(quran_duas), len(api_duas))):
        if i < len(api_duas):
            merged.append(api_duas[i])
        if i < len(quran_duas):
            merged.append(quran_duas[i])

    print('::notice title=rejected (final)::' + ', '.join(f'{k}: {v}' for k, v in REJECTED.most_common()))
    print(f'::notice title=selected::hadith {len(hadith)}, duas {len(api_duas)}, friday {len(friday)} of {len(ids)}')
    print(f'hadith {len(hadith)}, duas from API {len(api_duas)} (+{len(quran_duas)} Quranic), friday {len(friday)} (+{len(quran_friday)} ayahs)')
    if len(hadith) < MIN_HADITH or len(api_duas) < MIN_DUA_FROM_API:
        sys.exit('too few results: keeping the current file')

    out = {
        'meta': {
            'version': max(3, int(current.get('meta', {}).get('version', 0))),
            'hadith_source': 'HadeethEnc API (hadeethenc.com): grade صحيح, attribution متفق عليه, quoted verbatim; numbered from Sahih al-Bukhari',
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
