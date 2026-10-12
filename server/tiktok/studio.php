<?php
// Alqaree Studio: review the day's ومضة video and post it to TikTok (Login Kit + Content Posting API).
//   https://<site>/tiktok/studio.php?key=<secret>
// Follows TikTok's Content Sharing Guidelines: shows the creator, no default privacy, interaction
// settings off by default and greyed out when the account disables them, commercial content
// disclosure, the consent line, a preview, and an editable caption.
require __DIR__ . '/lib.php';
check_secret();
$c = cfg();
$key = $_GET['key'];
$date = (string)($_GET['date'] ?? date('Y-m-d'));
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
    fail(400, 'bad date');
}

// ---- JSON actions ---------------------------------------------------------------------------
if (($_GET['action'] ?? '') === 'post' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    set_time_limit(300);
    $in = json_decode((string)file_get_contents('php://input'), true) ?: [];
    $creator = api('/v2/post/publish/creator_info/query/', []);
    $privacy = (string)($in['privacy_level'] ?? '');
    if (!in_array($privacy, $creator['privacy_level_options'] ?? [], true)) {
        fail(400, 'Choose who can view this video.');
    }
    $brand = !empty($in['commercial']);
    $yourBrand = $brand && !empty($in['your_brand']);
    $branded = $brand && !empty($in['branded_content']);
    if ($brand && !$yourBrand && !$branded) {
        fail(400, 'Choose what you are promoting, or turn off content disclosure.');
    }
    if ($branded && $privacy === 'SELF_ONLY') {
        fail(400, 'Branded content cannot be private.');
    }
    $day = fetch_day($date);
    $title = mb_substr(trim((string)($in['title'] ?? '')), 0, 2200);
    $result = publish_video($day['video'], [
        'title'                    => $title,
        'privacy_level'            => $privacy,
        'disable_comment'          => !empty($creator['comment_disabled']) || empty($in['allow_comment']),
        'disable_duet'             => !empty($creator['duet_disabled']) || empty($in['allow_duet']),
        'disable_stitch'           => !empty($creator['stitch_disabled']) || empty($in['allow_stitch']),
        'video_cover_timestamp_ms' => 4600,
        'brand_content_toggle'     => $branded,
        'brand_organic_toggle'     => $yourBrand,
    ]);
    out(200, ['ok' => true, 'date' => $date] + mark_posted($date, $result, $privacy, 'studio'));
    exit;
}

if (($_GET['action'] ?? '') === 'video') {
    // Served from here with the right type: GitHub sends release files as downloads.
    $day = fetch_day($date);
    header('Content-Type: video/mp4');
    header('Content-Length: ' . strlen($day['video']));
    header('Cache-Control: private, max-age=3600');
    echo $day['video'];
    exit;
}

// ---- Page -----------------------------------------------------------------------------------
$tokens = read_json('tokens.json');
$creator = null;
$caption = '';
$videoUrl = 'studio.php?' . http_build_query(['key' => $key, 'date' => $date, 'action' => 'video']);
if ($tokens) {
    $creator = api('/v2/post/publish/creator_info/query/', []);
    [$s, $body] = http('GET', rtrim($c['video_base'], '/') . "/wamda-$date.txt");
    $caption = $s === 200 ? trim($body) : '';
}
$posted = (read_json('posted.json') ?? [])[$date] ?? null;
$h = fn($s) => htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8');
$labels = [
    'PUBLIC_TO_EVERYONE'    => 'Everyone',
    'MUTUAL_FOLLOW_FRIENDS' => 'Friends',
    'FOLLOWER_OF_CREATOR'   => 'Followers',
    'SELF_ONLY'             => 'Only me',
];
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alqaree Studio</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700&display=swap" rel="stylesheet">
<style>
:root{--bg:#060d2b;--card:#0c1847;--field:#101f57;--text:#eef2ff;--muted:#a9b4d6;--accent:#3ea6ff;--line:#22306b;--danger:#ff7a7a;--ok:#5fd39a}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.6 "Tajawal",system-ui,sans-serif}
main{max-width:980px;margin:0 auto;padding:28px 16px 64px}
header{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:22px}
.brand{display:flex;align-items:center;gap:10px;font-weight:700;font-size:20px}
.brand img{width:36px;height:36px;border-radius:10px}
.who{display:flex;align-items:center;gap:10px;color:var(--muted);font-size:14px}
.who img{width:34px;height:34px;border-radius:50%}
.who b{color:var(--text)}
.grid{display:grid;grid-template-columns:minmax(0,320px) minmax(0,1fr);gap:22px}
@media (max-width:760px){.grid{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:18px}
video{width:100%;aspect-ratio:9/16;border-radius:14px;background:#000;display:block}
label.t{display:block;font-weight:700;margin:16px 0 6px}
label.t:first-child{margin-top:0}
textarea,select,input[type=date]{width:100%;background:var(--field);color:var(--text);border:1px solid var(--line);border-radius:12px;padding:10px 12px;font:inherit}
textarea{min-height:150px;resize:vertical}
.row{display:flex;gap:18px;flex-wrap:wrap}
.check{display:flex;align-items:center;gap:8px;color:var(--text)}
.check.off{color:var(--muted);opacity:.55}
.hint{color:var(--muted);font-size:13px;margin:4px 0 0}
.switch{display:flex;justify-content:space-between;align-items:center;gap:12px}
.sub{margin:10px 0 0 4px;display:none}
.sub.on{display:block}
.consent{color:var(--muted);font-size:13px;margin:16px 0 0}
.consent a{color:var(--accent)}
button,.btn{appearance:none;border:0;border-radius:999px;padding:12px 22px;font:inherit;font-weight:700;cursor:pointer;text-decoration:none;display:inline-block}
.primary{background:var(--accent);color:#04102e;width:100%;margin-top:16px}
.primary:disabled{opacity:.4;cursor:not-allowed}
.msg{margin-top:12px;font-size:14px}
.msg.err{color:var(--danger)}.msg.ok{color:var(--ok)}
.center{text-align:center;padding:48px 18px}
.center p{color:var(--muted)}
</style>
</head>
<body>
<main>
<header>
  <div class="brand"><img src="data:image/png;base64,<?= base64_encode((string)@file_get_contents(__DIR__ . '/icon.png')) ?>" alt="">Alqaree Studio</div>
  <?php if ($creator): ?>
    <div class="who">
      <?php if (!empty($creator['creator_avatar_url'])): ?><img src="<?= $h($creator['creator_avatar_url']) ?>" alt=""><?php endif; ?>
      <span>Posting to <b><?= $h($creator['creator_nickname'] ?? '') ?></b> (@<?= $h($creator['creator_username'] ?? '') ?>)</span>
    </div>
  <?php endif; ?>
</header>

<?php if (!$creator): ?>
  <div class="card center">
    <h2>Connect your TikTok account</h2>
    <p>Alqaree Studio posts the daily ومضة video (a Quran verse, hadith or dua) to your TikTok account.<br>Log in with TikTok to continue.</p>
    <a class="btn primary" style="width:auto" href="auth.php?key=<?= $h(urlencode($key)) ?>">Continue with TikTok</a>
  </div>
<?php else: ?>
  <div class="grid">
    <div class="card">
      <label class="t" for="date">Day</label>
      <input type="date" id="date" value="<?= $h($date) ?>" onchange="location.search='?key=<?= $h(urlencode($key)) ?>&date='+this.value">
      <label class="t">Preview</label>
      <video src="<?= $h($videoUrl) ?>" controls playsinline preload="metadata"></video>
    </div>

    <div class="card">
      <?php if ($posted): ?>
        <p class="msg ok">Already posted for this day (<?= $h($posted['status']) ?>, <?= $h($labels[$posted['privacy']] ?? $posted['privacy']) ?>).</p>
      <?php endif; ?>

      <label class="t" for="title">Caption</label>
      <textarea id="title" dir="auto" maxlength="2200"><?= $h($caption) ?></textarea>

      <label class="t" for="privacy">Who can view this video</label>
      <select id="privacy" required>
        <option value="" selected disabled>Select</option>
        <?php foreach ($creator['privacy_level_options'] ?? [] as $p): ?>
          <option value="<?= $h($p) ?>"><?= $h($labels[$p] ?? $p) ?></option>
        <?php endforeach; ?>
      </select>

      <label class="t">Allow users to</label>
      <div class="row">
        <?php foreach (['comment' => 'Comment', 'duet' => 'Duet', 'stitch' => 'Stitch'] as $k => $name):
            $off = !empty($creator[$k . '_disabled']); ?>
          <label class="check<?= $off ? ' off' : '' ?>"><input type="checkbox" id="allow_<?= $k ?>" <?= $off ? 'disabled' : '' ?>> <?= $name ?></label>
        <?php endforeach; ?>
      </div>

      <label class="t">Disclose video content</label>
      <div class="switch">
        <span class="hint" style="margin:0">Turn on to disclose that this video promotes goods or services in exchange for something of value.</span>
        <input type="checkbox" id="commercial" onchange="sync()">
      </div>
      <div class="sub" id="commercialOptions">
        <label class="check"><input type="checkbox" id="your_brand" onchange="sync()"> Your brand <span class="hint">— promoting yourself or your own business</span></label>
        <label class="check"><input type="checkbox" id="branded_content" onchange="sync()"> Branded content <span class="hint">— promoting another brand or a third party</span></label>
        <p class="hint" id="brandNote"></p>
      </div>

      <p class="consent" id="consent">By posting, you agree to TikTok's <a href="https://www.tiktok.com/legal/page/global/music-usage-confirmation/en" target="_blank" rel="noopener">Music Usage Confirmation</a>.</p>

      <button class="primary" id="post" onclick="post()" disabled>Post to TikTok</button>
      <div class="msg" id="msg"></div>
    </div>
  </div>
<?php endif; ?>
</main>

<script>
const $ = id => document.getElementById(id);
function sync() {
  if (!$('post')) return;
  const commercial = $('commercial').checked;
  $('commercialOptions').classList.toggle('on', commercial);
  const branded = commercial && $('branded_content').checked;
  const yours = commercial && $('your_brand').checked;
  // Branded content cannot be private.
  const onlyMe = [...$('privacy').options].find(o => o.value === 'SELF_ONLY');
  if (onlyMe) { onlyMe.disabled = branded; if (branded && $('privacy').value === 'SELF_ONLY') $('privacy').value = ''; }
  $('brandNote').textContent = branded ? 'Your video will be labeled "Paid partnership".' : yours ? 'Your video will be labeled "Promotional content".' : '';
  const policy = branded ? '<a href="https://www.tiktok.com/legal/page/global/bc-policy/en" target="_blank" rel="noopener">Branded Content Policy</a> and ' : '';
  $('consent').innerHTML = 'By posting, you agree to TikTok\'s ' + policy + '<a href="https://www.tiktok.com/legal/page/global/music-usage-confirmation/en" target="_blank" rel="noopener">Music Usage Confirmation</a>.';
  $('post').disabled = !$('privacy').value || (commercial && !branded && !yours);
}
if ($('privacy')) $('privacy').addEventListener('change', sync);

async function post() {
  const btn = $('post'), msg = $('msg');
  btn.disabled = true; msg.className = 'msg'; msg.textContent = 'Uploading to TikTok…';
  const body = {
    title: $('title').value, privacy_level: $('privacy').value,
    allow_comment: $('allow_comment').checked, allow_duet: $('allow_duet').checked, allow_stitch: $('allow_stitch').checked,
    commercial: $('commercial').checked, your_brand: $('your_brand').checked, branded_content: $('branded_content').checked,
  };
  try {
    const r = await fetch(location.pathname + location.search + '&action=post', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    const j = await r.json();
    if (!j.ok) throw new Error(j.error || 'Failed');
    msg.className = 'msg ok';
    msg.textContent = 'Posted. It can take a few minutes for the video to appear on your profile.';
  } catch (e) {
    msg.className = 'msg err'; msg.textContent = e.message; btn.disabled = false;
  }
}
</script>
</body>
</html>
