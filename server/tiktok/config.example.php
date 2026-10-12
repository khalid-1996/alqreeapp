<?php
// Copy to config.php and fill in. config.php and data/ must never be public in git.
return [
    // developers.tiktok.com > your app > App details
    'client_key'    => 'PUT_CLIENT_KEY',
    'client_secret' => 'PUT_CLIENT_SECRET',
    // Must match a Redirect URI registered in the app (Login Kit), exactly.
    'redirect_uri'  => 'https://khalid96.net/tiktok/callback.php',

    // A long random string. n8n calls post.php?key=<this>. Also protects auth.php.
    'secret'        => 'PUT_A_LONG_RANDOM_STRING',

    // SELF_ONLY until TikTok audits the app (unaudited apps can only post privately).
    // After the audit: PUBLIC_TO_EVERYONE.
    'privacy_level' => 'SELF_ONLY',

    // Where the daily videos are published (GitHub Actions renders them every night).
    'video_base'    => 'https://github.com/khalid-1996/alqreeapp/releases/download/wamda-videos',
    'timezone'      => 'Asia/Dubai',

    // Folder for tokens and the post log (keep data/.htaccess, or put it outside the web root).
    'data_dir'      => __DIR__ . '/data',
];
