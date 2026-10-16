# YTGet

Private Android-only Flutter app: paste a YouTube link → preview → download MP3/MP4 on-phone. No websites, no servers, no accounts.

## How it works

- UI in Flutter; downloads run **on-device** via
  [`youtubedl-android`](https://github.com/JunkFood02/youtubedl-android)
  (`io.github.junkfood02.youtubedl-android:library` + `:ffmpeg`, Maven Central),
  bridged over a MethodChannel/EventChannel (`YtDlpBridge.kt`).
- That library bundles Python + yt-dlp + ffmpeg inside the APK (hence ~60 MB for arm64).
- Pure-Dart extractors are NOT used: since Aug 2026 YouTube's PO-token
  requirement truncates them to ~60 s. yt-dlp handles it.

## Legal — read this

- **Personal use only.** Only download your own videos, Creative Commons /
  openly licensed content, or content you have explicit permission for.
- Unauthorized downloading violates YouTube's Terms of Service.
- This app is **sideload-only** and will never go on the Play Store
  (YouTube downloaders are banned there).

## Build

Prereqs: Flutter 3.47+, Android SDK 37.

```bash
cd app
/opt/flutter/bin/flutter pub get
/opt/flutter/bin/flutter analyze && /opt/flutter/bin/flutter test
/opt/flutter/bin/flutter build apk --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

> Use `/opt/flutter/bin/flutter` directly — the `/usr/bin/flutter` wrapper
> misbehaves inside git worktrees.

## Sideload to your phone

```bash
adb install app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Or copy the APK to the phone (USB / QuickDrop / LocalSend) and tap it
(allow "Install unknown apps" for Files).

## Use

1. Paste a link or **Share → YTGet** from the YouTube app.
2. Preview title/thumbnail, pick MP3 (128/192/320 kbps) or MP4 (720p/1080p).
3. Download → saved to `Download/YTGet/`. Open/share from History.

First launch initializes the engine (extracts Python, a few seconds).

## When YouTube breaks downloads

yt-dlp needs updates a few times a year. In-app: **Settings → Update**.
It pulls the STABLE channel. If that fails, bump
`io.github.junkfood02.youtubedl-android` to the latest in
`app/android/app/build.gradle.kts` and rebuild.

## Layout

```
app/lib/core/youtube_url.dart     URL validation (unit-tested)
app/lib/core/download_args.dart   yt-dlp option builders (unit-tested)
app/lib/core/progress_parser.dart legacy process parser (unit-tested)
app/lib/core/ytdlp_service.dart   VideoMeta + process runner (desktop/fallback)
app/lib/core/native_ytdlp.dart    MethodChannel/EventChannel client (used at runtime)
app/lib/core/binary_manager.dart  (superseded by native lib, kept for reference)
app/lib/core/history_store.dart   download history (shared_prefs)
app/lib/ui/home_page.dart         main UI + settings
app/android/.../YtDlpBridge.kt    Kotlin bridge: init/info/download/cancel/update
docs/superpowers/specs/           design spec
docs/superpowers/plans/           implementation plan
```
