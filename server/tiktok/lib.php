<?php
// Shared helpers for the TikTok poster: config, HTTP, tokens, log.

const TIKTOK_AUTH_URL = 'https://www.tiktok.com/v2/auth/authorize/';
const SCOPES = 'user.info.basic,video.publish';

function cfg(): array
{
    static $c;
    if ($c === null) {
        $file = __DIR__ . '/config.php';
        if (!is_file($file)) {
            fail(500, 'config.php is missing: copy config.example.php to config.php and fill it in');
        }
        $c = require $file;
        $c['api'] = $c['api'] ?? 'https://open.tiktokapis.com';  // overridable for tests
        if (!is_dir($c['data_dir'])) {
            mkdir($c['data_dir'], 0700, true);
        }
        date_default_timezone_set($c['timezone']);
    }
    return $c;
}

function out(int $code, array $body): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT), "\n";
}

function fail(int $code, string $error, array $extra = []): void
{
    log_line(['error' => $error] + $extra);
    out($code, ['ok' => false, 'error' => $error] + $extra);
    exit;
}

function check_secret(): void
{
    $key = $_GET['key'] ?? '';
    if (!is_string($key) || !hash_equals(cfg()['secret'], $key)) {
        fail(403, 'bad key');
    }
}

function data_file(string $name): string
{
    return cfg()['data_dir'] . '/' . $name;
}

function read_json(string $name): ?array
{
    $f = data_file($name);
    return is_file($f) ? json_decode((string)file_get_contents($f), true) : null;
}

function write_json(string $name, array $value): void
{
    $f = data_file($name);
    file_put_contents($f . '.tmp', json_encode($value, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    rename($f . '.tmp', $f);
    @chmod($f, 0600);
}

function log_line(array $entry): void
{
    $line = json_encode(['at' => date('c')] + $entry, JSON_UNESCAPED_UNICODE) . "\n";
    @file_put_contents(cfg()['data_dir'] . '/post.log', $line, FILE_APPEND);
}

/** HTTP request. Returns [status, body string]. */
function http(string $method, string $url, array $headers = [], ?string $body = null, int $timeout = 60): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,  // GitHub release downloads redirect to their storage
        CURLOPT_MAXREDIRS      => 5,
        CURLOPT_TIMEOUT        => $timeout,
        CURLOPT_HTTPHEADER     => $headers,
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    }
    $res = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);
    if ($res === false) {
        fail(502, "network: $err", ['url' => $url]);
    }
    return [$status, (string)$res];
}

/** TikTok JSON API call with the user's access token. Fails unless error.code is "ok". */
function api(string $path, array $payload): array
{
    [$status, $body] = http('POST', cfg()['api'] . $path, [
        'Authorization: Bearer ' . access_token(),
        'Content-Type: application/json; charset=UTF-8',
    ], json_encode($payload, JSON_UNESCAPED_UNICODE));
    $j = json_decode($body, true) ?: [];
    if ($status !== 200 || ($j['error']['code'] ?? '') !== 'ok') {
        fail(502, "tiktok $path: " . ($j['error']['code'] ?? $status) . ' ' . ($j['error']['message'] ?? ''), ['response' => $j ?: $body]);
    }
    return $j['data'] ?? [];
}

/** Token endpoint (authorization_code or refresh_token). Saves and returns the tokens. */
function token_request(array $fields): array
{
    $c = cfg();
    [$status, $body] = http('POST', $c['api'] . '/v2/oauth/token/', [
        'Content-Type: application/x-www-form-urlencoded',
        'Cache-Control: no-cache',
    ], http_build_query($fields + ['client_key' => $c['client_key'], 'client_secret' => $c['client_secret']]));
    $j = json_decode($body, true) ?: [];
    if ($status !== 200 || empty($j['access_token'])) {
        fail(502, 'tiktok token: ' . ($j['error'] ?? $status) . ' ' . ($j['error_description'] ?? ''), ['response' => $j ?: $body]);
    }
    $now = time();
    $t = [
        'access_token'       => $j['access_token'],
        'refresh_token'      => $j['refresh_token'],
        'open_id'            => $j['open_id'] ?? null,
        'scope'              => $j['scope'] ?? null,
        'expires_at'         => $now + (int)($j['expires_in'] ?? 86400),
        'refresh_expires_at' => $now + (int)($j['refresh_expires_in'] ?? 31536000),
    ];
    write_json('tokens.json', $t);
    return $t;
}

/** A valid access token, refreshed when it is about to expire (it lasts 24 hours). */
function access_token(): string
{
    $t = read_json('tokens.json');
    if (!$t) {
        fail(401, 'not connected: open auth.php?key=<secret> once and log in with the TikTok account');
    }
    if ($t['expires_at'] - time() < 600) {
        if ($t['refresh_expires_at'] <= time()) {
            fail(401, 'TikTok login expired (1 year): open auth.php?key=<secret> again');
        }
        $t = token_request(['grant_type' => 'refresh_token', 'refresh_token' => $t['refresh_token']]);
    }
    return $t['access_token'];
}
