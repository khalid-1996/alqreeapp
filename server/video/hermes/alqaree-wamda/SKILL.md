---
name: alqaree-wamda
description: Get the day's ومضة video (hadith, dua or ayah) for the القارئ TikTok account from the home video service, send it with its caption, and re-render on request.
---

# ومضة اليوم — TikTok video

The `alqaree-video` container on the home server renders one vertical video (1080x1920, 8 s) per day
from the القارئ app's own content. Never write, translate, shorten or "fix" the Quran or hadith text:
it is copied verbatim from the service, which copies it from the app.

Service: `http://alqaree-video:8090` (same Docker network) or `http://<server-ip>:8090`.

| Need | Call |
|---|---|
| Today's ومضة | `GET /today` |
| Tomorrow's | `GET /tomorrow` |
| A given day | `GET /day/YYYY-MM-DD` |
| Re-render a day | `GET /render?date=YYYY-MM-DD&force=1` |
| Health | `GET /health` |

Each returns JSON: `date`, `type` (hadith | dua | ayah), `text`, `source`, `url` (hadith explanation
page, may be null), `caption` (ready to paste, with hashtags), `video` (mp4 URL), `poster` (png URL).
A day that is not rendered yet is rendered on the call; that takes about two minutes.

## Daily delivery (schedule: every day at 07:00 Asia/Dubai)

1. `curl -sf http://alqaree-video:8090/today` and read the JSON.
2. Download the video: `curl -sf -o /tmp/wamda-<date>.mp4 "<video>"`.
3. Send Khalid one message on Telegram with the video attached and this text, exactly:
   - first line: `ومضة اليوم · <حديث|دعاء|آية>` (from `type`)
   - then the `caption` field unchanged (he copies it into TikTok).
4. Do not post anywhere else. Khalid posts to TikTok himself.

## On request

- "ومضة بكرة" / "tomorrow" → same as above with `/tomorrow`.
- "عيد الفيديو" / "re-render" → `/render?date=<date>&force=1`, then send the new video.
- "يوم 2026-10-20" → `/day/2026-10-20`.

## If something fails

- `/health` does not answer → tell Khalid: "خدمة فيديو ومضات متوقفة (alqaree-video)". Do not try to
  make a video yourself.
- An HTTP 500 → send him the `error` field as is.
