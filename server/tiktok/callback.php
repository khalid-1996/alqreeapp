<?php
// Step 2 of the one-time login: TikTok redirects here with ?code=...&state=...
require __DIR__ . '/lib.php';

if (isset($_GET['error'])) {
    fail(400, 'TikTok login refused: ' . $_GET['error'] . ' ' . ($_GET['error_description'] ?? ''));
}
$saved = read_json('oauth_state.json');
$state = $_GET['state'] ?? '';
if (!isset($_GET['code'])) {
    fail(400, 'callback.php works. Do not open it directly: start from studio.php (Continue with TikTok).');
}
if (!$saved) {
    fail(400, 'No login was started from this folder, or data/ is not writable: ' . cfg()['data_dir']
        . '. Start from studio.php in the same folder as this callback.php.');
}
if (!is_string($state) || !hash_equals($saved['state'], $state)) {
    fail(400, 'This TikTok answer belongs to an older login. Start again from studio.php.');
}
if (time() - $saved['at'] > 900) {
    fail(400, 'The login took more than 15 minutes. Start again from studio.php.');
}
@unlink(data_file('oauth_state.json'));
$code = $_GET['code'] ?? '';
if (!is_string($code) || $code === '') {
    fail(400, 'missing code');
}
$t = token_request([
    'grant_type'   => 'authorization_code',
    'code'         => $code,
    'redirect_uri' => cfg()['redirect_uri'],
]);
log_line(['connected' => $t['open_id'], 'scope' => $t['scope']]);
header('Location: studio.php?' . http_build_query(['key' => cfg()['secret']]));
