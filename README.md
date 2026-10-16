# YTGet 📥

<p align="center">
  <img src="docs/assets/logo.png" width="160" alt="YTGet logo">
</p>

<p align="center">
  <b>Paste a YouTube link → get MP3/MP4 on your phone. No sketchy sites, no servers, no accounts.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Android%20only-green" alt="Android only">
  <img src="https://img.shields.io/badge/Flutter-3.47-blue" alt="Flutter">
  <img src="https://img.shields.io/badge/license-see_LICENSE-lightgrey" alt="License">
</p>

> Save the generated logo as `docs/assets/logo.png` (see "Logo" below).

---

## ✨ Features

- 🔗 **Paste a link or Share → YTGet** straight from the YouTube app
- 🖼️ **Preview first** — title, thumbnail, duration before you download
- 🎵 **MP3** at 128 / 192 / 320 kbps · 🎬 **MP4** at 720p / 1080p
- 📊 Live progress with cancel
- 🕘 Download history — open or share files right from the app
- 🔄 In-app yt-dlp updater for when YouTube changes things
- 🔒 **100% on-device.** No backend, no analytics, no ads, no accounts

## 📱 Screenshots

_Coming soon — drop screenshots in `docs/assets/` and link them here._

## 🚀 Install (no build needed)

1. Grab `app-arm64-v8a-release.apk` from
   [Releases](https://github.com/AromalBiju1/YTGet/releases)
   (most phones are arm64).
2. Copy it to your phone (USB / QuickDrop / LocalSend) and tap it.
3. Allow **"Install unknown apps"** when asked.
4. Open YTGet, wait a few seconds on first launch (engine setup), done.

```bash
# or via USB debugging:
adb install app-arm64-v8a-release.apk
```

## 🧭 Usage

1. Copy a YouTube link — or tap **Share → YTGet** inside the YouTube app.
2. Hit **Preview** to confirm it's the right video.
3. Pick the **MP3 / MP4** tab and a quality.
4. Hit **Download**. Files land in `Download/YTGet/`.
5. Open or share them anytime from **History**.

## 🛠️ Build from source

Prereqs: Flutter 3.47+, Android SDK 37.

```bash
cd app
flutter pub get
flutter analyze && flutter test
flutter build apk --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 🧠 How it works

```
Flutter UI ──MethodChannel/EventChannel──▶ YtDlpBridge.kt
                                                  │  (youtubedl-android: Python + yt-dlp + ffmpeg, on-device)
                                                  ▼
                                          Download/YTGet/
```

- Pure-Dart extractors are deliberately **not** used: since Aug 2026,
  YouTube's PO-token requirement truncates them to ~60 s. yt-dlp handles it.
- The ~60 MB APK size is the bundled Python + ffmpeg runtimes.

## 🗂️ Project layout

```
app/lib/core/youtube_url.dart     URL validation (unit-tested)
app/lib/core/download_args.dart   yt-dlp option builders (unit-tested)
app/lib/core/progress_parser.dart progress-line parser (unit-tested)
app/lib/core/native_ytdlp.dart    MethodChannel/EventChannel client (runtime path)
app/lib/core/ytdlp_service.dart   VideoMeta model + desktop process runner (reference)
app/lib/core/binary_manager.dart  (superseded by the native lib, kept for reference)
app/lib/core/history_store.dart   download history (shared_prefs)
app/lib/ui/home_page.dart         main UI + settings
app/android/.../YtDlpBridge.kt    Kotlin bridge: init / info / download / cancel / update
docs/superpowers/specs/           design spec
docs/superpowers/plans/           implementation plan
```

## 🎨 Logo

Generate with the prompt in the chat (or your own), then:

1. Save the icon as `docs/assets/logo.png` (README showcase).
2. To also make it the **app launcher icon**:
   ```bash
   cd app
   flutter pub add dev:flutter_launcher_icons
   ```
   Add to `pubspec.yaml`:
   ```yaml
   flutter_launcher_icons:
     android: true
     image_path: "assets/logo.png"
   ```
   ```bash
   cp <your-logo>.png assets/logo.png
   dart run flutter_launcher_icons
   flutter build apk --split-per-abi
   ```

## ❓ Troubleshooting

| Problem | Fix |
|---|---|
| Downloads fail after working fine | YouTube changed something → **Settings → Update** |
| Update fails | Bump `io.github.junkfood02.youtubedl-android` in `app/android/app/build.gradle.kts` and rebuild |
| "Engine init failed" on launch | Reinstall the APK for your ABI (usually arm64) |
| Share menu doesn't show YTGet | Reinstall; Android registers the share target at install time |
| No `test/` found when running flutter | Run flutter commands from inside `app/`, not the repo root |

## ⚖️ Legal — read this

- **Personal use only.** Only download your own videos, Creative Commons /
  openly-licensed content, or content you have explicit permission for.
- Unauthorized downloading violates YouTube's Terms of Service.
- Sideload-only by design — YouTube downloaders are banned from the Play Store,
  so this app will never be published there.

## 🤝 Contributing

Issues and PRs welcome. Run `flutter analyze && flutter test` before pushing.
For big changes, open an issue first to discuss.

## 📄 License

See [LICENSE](./LICENSE).
