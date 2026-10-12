<?php
// Step 2 of the one-time login: TikTok redirects here with ?code=...&state=...
require __DIR__ . '/lib.php';

if (isset($_GET['error'])) {
    fail(400, 'TikTok login refused: ' . $_GET['error'] . ' ' . ($_GET['error_description'] ?? ''));
}
$saved = read_json('oauth_state.json');
$state = $_GET['state'] ?? '';
if (!$saved || !is_string($state) || !hash_equals($saved['state'], $state) || time() - $saved['at'] > 900) {
    fail(400, 'bad or expired state: start again from auth.php');
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
