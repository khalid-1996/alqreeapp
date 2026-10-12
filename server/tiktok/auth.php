<?php
// Step 1 of the one-time login: https://khalid96.net/tiktok/auth.php?key=<secret>
require __DIR__ . '/lib.php';
check_secret();

$state = bin2hex(random_bytes(16));
write_json('oauth_state.json', ['state' => $state, 'at' => time()]);
$c = cfg();
header('Location: ' . TIKTOK_AUTH_URL . '?' . http_build_query([
    'client_key'    => $c['client_key'],
    'scope'         => SCOPES,
    'response_type' => 'code',
    'redirect_uri'  => $c['redirect_uri'],
    'state'         => $state,
]));
