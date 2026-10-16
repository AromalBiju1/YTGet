# YTGet Design — 2026-10-16

## Goal
Private Android Flutter app to convert YouTube → MP3/MP4 on-phone, no sketchy websites. Sideload APK only.

## Decisions (user-approved)
- Platform: Android only (sideload, no Play Store — YT downloaders banned)
- Engine: on-phone only, Flutter + bundled yt-dlp binary + ffmpeg
- Why not pure-Dart: as of Aug 2026 YouTube requires PO Token, youtube_explode_dart truncates to ~60s. yt-dlp + JS runtime required.
- Scope day1: paste link / share-sheet → preview title/thumb/duration → pick MP3/MP4 + quality → progress → save to Download/YTGet → history/open/share.

## Architecture
Single Flutter app, no backend.
UI (Material3) -> DownloaderService -> Process runners:
- `yt-dlp --dump-json <url>` for metadata
- `yt-dlp -x --audio-format mp3 --audio-quality <k> -o <file>` for MP3
- `yt-dlp -f bv*[height<=H]+ba/b --merge-output-format mp4 -o <file>` for MP4 (ffmpeg merges, prefer h264)
- `ffmpeg-kit` or bundled ffmpeg binary for conversion/merge
Storage: app cache during download, then MediaStore to `Download/YTGet/`. History in drift/sqlite or shared_prefs (file path, title, thumb url, date, format).

Binaries: yt-dlp android arm64 (+armv7/x86_64 fallback) in assets/nativeLibs, chmod +x on first run. Update screen pulls latest release from github.com/yt-dlp/yt-dlp.

Permissions: INTERNET, READ/WRITE_EXTERNAL (legacy max), POST_NOTIFICATIONS (progress), FOREGROUND_SERVICE_DATA, REQUEST_INSTALL? no. Scoped storage via MediaStore on Android 10+.

## Components
1. `UrlInput`: TextField + Paste + Validate (youtube.com/watch, youtu.be, shorts, music). + `receive_sharing_intent` for Share from YT app.
2. `PreviewCard`: thumbnail (cached_network_image), title, author, duration.
3. `FormatPicker`: tabs MP3 (128/192/320) / MP4 (720p/1080p/best). Shows est. size from dump-json filesize_approx.
4. `DownloadTile`: progress %/speed/ETA parsed from yt-dlp `--newline --progress` output, cancel button, expandable log.
5. `HistoryList`: open with open_filex, share with share_plus, delete, re-download.
6. `Settings`: yt-dlp version + Update, ffmpeg check, download folder, theme, disclaimer.

## Data flow
1. User pastes/shares URL → validate → `yt-dlp --dump-json --no-playlist`
2. Parse JSON → preview
3. User picks format → build args → spawn process in foreground service / WorkManager
4. Pipe stdout → parse `[download] 12.5%` → UI stream
5. On complete → MediaStore scan → insert history → notification tap to open

## Error handling
- Invalid URL: inline error
- Private/deleted/age-restricted/login-required: show yt-dlp stderr friendly + no retry loop
- No network / timeout: retry button
- YouTube spec change (ERROR: signature): prompt "Update yt-dlp" button
- Storage denied/full, ffmpeg missing: blocking dialog with fix steps
- Always show expandable raw log for debug

## Testing
- Unit: URL parser (watch, youtu.be, shorts, playlist reject v1), progress-line parser
- Integration (manual on emulator + real arm64): dump-json on public test video (e.g. BigBuckBunny), 720p MP4, 192k MP3, cancel mid-download
- Build: `flutter build apk --split-per-abi`, install via `adb install`, verify no Play-services dependency

## Legal / distribution
- Sideload only. No Play Store upload.
- Personal use only: own videos, CC-licensed, or with permission. YouTube ToS prohibits unauthorized downloading. Include disclaimer in app + README.
- No analytics, no servers, no ads.

## Out of scope v1
- iOS, playlists, background playlists queue, subtitles, SponsorBlock, auto-update via store.
