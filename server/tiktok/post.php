<?php
// Posts the day's ومضة video to TikTok without a person (n8n or cron):
//   https://<site>/tiktok/post.php?key=<secret>
// Optional: &date=YYYY-MM-DD, &dry=1 (check everything, post nothing), &force=1 (post again).
// Safe to call more than once: a day that is already posted is skipped.
require __DIR__ . '/lib.php';
check_secret();
set_time_limit(300);

$c = cfg();
$date = (string)($_GET['date'] ?? date('Y-m-d'));
$dry = ($_GET['dry'] ?? '') === '1';
$force = ($_GET['force'] ?? '') === '1';

$posted = read_json('posted.json') ?? [];
if (isset($posted[$date]) && !$force && !$dry) {
    out(200, ['ok' => true, 'skipped' => 'already posted', 'date' => $date] + $posted[$date]);
    exit;
}

$day = fetch_day($date);
$creator = api('/v2/post/publish/creator_info/query/', []);
$privacy = $c['privacy_level'];
if (!in_array($privacy, $creator['privacy_level_options'] ?? [], true)) {
    fail(409, "privacy '$privacy' not allowed for this account now", ['allowed' => $creator['privacy_level_options'] ?? []]);
}
$title = mb_substr($day['caption'], 0, 2200);
if ($dry) {
    out(200, ['ok' => true, 'dry_run' => true, 'date' => $date, 'bytes' => strlen($day['video']), 'privacy' => $privacy,
              'account' => $creator['creator_nickname'] ?? null, 'caption' => $title]);
    exit;
}

$result = publish_video($day['video'], [
    'title'                    => $title,
    'privacy_level'            => $privacy,
    'disable_comment'          => (bool)($creator['comment_disabled'] ?? false),
    'disable_duet'             => (bool)($creator['duet_disabled'] ?? false),
    'disable_stitch'           => (bool)($creator['stitch_disabled'] ?? false),
    'video_cover_timestamp_ms' => 4600,
]);
out(200, ['ok' => true, 'date' => $date] + mark_posted($date, $result, $privacy, 'auto'));
