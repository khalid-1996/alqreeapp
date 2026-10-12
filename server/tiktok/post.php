<?php
// Posts today's ومضة video to TikTok. Called once a day by n8n (or cron):
//   https://khalid96.net/tiktok/post.php?key=<secret>
// Optional: &date=YYYY-MM-DD (a given day), &dry=1 (check everything, post nothing), &force=1 (post again).
// Safe to call more than once: a day that is already posted is skipped.
require __DIR__ . '/lib.php';
check_secret();
set_time_limit(300);

$c = cfg();
$date = $_GET['date'] ?? date('Y-m-d');
if (!is_string($date) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
    fail(400, 'bad date');
}
$dry = ($_GET['dry'] ?? '') === '1';
$force = ($_GET['force'] ?? '') === '1';

$posted = read_json('posted.json') ?? [];
if (isset($posted[$date]) && !$force && !$dry) {
    out(200, ['ok' => true, 'skipped' => 'already posted', 'date' => $date] + $posted[$date]);
    exit;
}

// 1. The day's video and caption (rendered every night by GitHub Actions).
$base = rtrim($c['video_base'], '/') . "/wamda-$date";
[$s, $video] = http('GET', "$base.mp4", [], null, 120);
if ($s !== 200 || strlen($video) < 100000) {
    fail(404, "video for $date is not published yet ($s)", ['url' => "$base.mp4"]);
}
[$s, $caption] = http('GET', "$base.txt");
if ($s !== 200 || trim($caption) === '') {
    fail(404, "caption for $date is not published yet ($s)");
}
$title = mb_substr(trim($caption), 0, 2200);  // TikTok caption limit
$size = strlen($video);

// 2. The account's allowed privacy levels (TikTok requires asking before each post).
$creator = api('/v2/post/publish/creator_info/query/', []);
$privacy = $c['privacy_level'];
if (!in_array($privacy, $creator['privacy_level_options'] ?? [], true)) {
    fail(409, "privacy '$privacy' not allowed for this account now", ['allowed' => $creator['privacy_level_options'] ?? []]);
}
if ($dry) {
    out(200, ['ok' => true, 'dry_run' => true, 'date' => $date, 'bytes' => $size, 'privacy' => $privacy,
              'account' => $creator['creator_nickname'] ?? null, 'caption' => $title]);
    exit;
}

// 3. Start the post, upload the file in one chunk, then follow its status.
$init = api('/v2/post/publish/video/init/', [
    'post_info' => [
        'title'                    => $title,
        'privacy_level'            => $privacy,
        'disable_comment'          => false,
        'disable_duet'             => false,
        'disable_stitch'           => false,
        'video_cover_timestamp_ms' => 4600,
    ],
    'source_info' => [
        'source'            => 'FILE_UPLOAD',
        'video_size'        => $size,
        'chunk_size'        => $size,
        'total_chunk_count' => 1,
    ],
]);
$publishId = $init['publish_id'] ?? null;
$uploadUrl = $init['upload_url'] ?? null;
if (!$publishId || !$uploadUrl) {
    fail(502, 'tiktok init: no upload url', ['response' => $init]);
}
[$s, $body] = http('PUT', $uploadUrl, [
    'Content-Type: video/mp4',
    'Content-Length: ' . $size,
    'Content-Range: bytes 0-' . ($size - 1) . '/' . $size,
], $video, 180);
if ($s !== 200 && $s !== 201) {
    fail(502, "upload failed ($s)", ['response' => $body, 'publish_id' => $publishId]);
}

$status = 'PROCESSING_UPLOAD';
$detail = [];
for ($i = 0; $i < 12 && !in_array($status, ['PUBLISH_COMPLETE', 'FAILED'], true); $i++) {
    sleep(5);
    $detail = api('/v2/post/publish/status/fetch/', ['publish_id' => $publishId]);
    $status = $detail['status'] ?? $status;
}
if ($status === 'FAILED') {
    fail(502, 'tiktok publish failed: ' . ($detail['fail_reason'] ?? 'unknown'), ['publish_id' => $publishId]);
}

$posted[$date] = ['publish_id' => $publishId, 'status' => $status, 'privacy' => $privacy, 'at' => date('c')];
ksort($posted);
write_json('posted.json', array_slice($posted, -60, null, true));
log_line(['posted' => $date] + $posted[$date]);
out(200, ['ok' => true, 'date' => $date] + $posted[$date]);
