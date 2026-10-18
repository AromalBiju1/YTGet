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

---

## 🎯 Purpose

YTGet exists because YouTube-to-MP3/MP4 websites are one of the worst corners
of the internet: popup ads, fake download buttons, trackers, and malware.

This is a **personal, local replacement**: your phone downloads and converts
videos entirely on-device with yt-dlp + ffmpeg — the same open-source tools
that power every "converter site", running directly in your hands. Nothing is
uploaded, logged, or monetized. If YouTube changes its site, you update yt-dlp
from within the app and keep going.

It's a sideloaded tool for *your own* use: archived copies of your own uploads,
Creative Commons media, or content you have permission to save.

## ✨ Features

- 🔗 **Paste a link or Share → YTGet** straight from the YouTube app
- 🖼️ **Preview first** — title, thumbnail, duration before you download
- 🎵 **MP3** at 128 / 192 / 320 kbps · 🎬 **MP4** at 720p / 1080p
- 📊 Live progress with cancel — states flow **Downloading → Processing (merge) → Downloaded**
- 📁 **Choose where files go** — public `Download/YTGet`, app storage, or any
  custom folder on the device
- 🕚 **Dedicated History tab** — open, share, or delete entries, or clear the
  whole list; downloads finish even while you're browsing it
- 🚫 **Duplicate guard** — warns before re-downloading the same video, with a
  one-tap "Open file" shortcut
- 🔔 **Runs in the background** — switch tabs, lock the phone; a notification
  tells you when the file is ready
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
4. (Optional) Tap the **Save to** row to change where files are stored:
   **Downloads/YTGet** (public, recommended), **App storage** (private,
   no permission), or **Custom folder…** (browse the device).
5. Hit **Download**. To use the public Downloads folder or a custom location,
   grant **"Allow all files"** when asked.
6. Manage files in the **History** tab — open, share, delete single entries,
   or **Clear all**.

## ⚠️ Limitations (read before reporting a bug)

- **Android only, arm64 only.** No iOS, Windows, or armv7/x86_64 builds.
- **Downloads run without a foreground service.** They keep going while you
  browse other tabs, lock the screen, or background the app — but swiping
  YTGet away from Recents kills any ongoing download. Very long downloads on
  locked devices may also be throttled (Doze).
- **The bundled yt-dlp ages fast.** When YouTube changes its site, downloads
  break everywhere. Fix: **Settings → Update**; if that fails, wait for a new
  engine release upstream and rebuild.
- **"Allow all files" permission.** Writing to public storage (Downloads or a
  custom folder) needs the broad `MANAGE_EXTERNAL_STORAGE` grant — a
  deliberate trade-off for a sideload-only tool. App storage mode needs no
  permission, but those files sit in Android's private app directory.
- **~60 MB APK.** That's the price of shipping a complete Python + ffmpeg
  runtime for on-device conversion.
- **Hard-coded public path.** The public Downloads target assumes the standard
  primary partition (`/storage/emulated/0/Download`) — unusual multi-user or
  curved-storage setups may not resolve.
- **Debug-signed release.** The shipped APK is signed with debug keys; pin it
  or rebuild with your own release key if you distribute to others.
- **Playlists are rejected.** One video per download — `--no-playlist` is
  always on, and only single videos (`watch`, `youtu.be`, `shorts`, `embed`,
  `live`, `music.youtube`) parse.
- **Not for the Play Store.** YouTube downloaders are banned there; this app
  is intentionally a sideload-only project.

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
                                       Downloads/YTGet · App storage · Custom folder
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
app/lib/core/save_location.dart   chosen save-folder (mode + custom path)
app/lib/core/history_store.dart   download history (shared_prefs) + live controller
app/lib/core/app_notifier.dart    "download complete" notification helper
app/lib/ui/app_shell.dart         navigation shell: Download / History tabs + app bar
app/lib/ui/download_page.dart     download flow: link, preview, quality, folder, progress
app/lib/ui/history_page.dart      dedicated history screen (clear/delete/open/share)
app/lib/ui/settings_page.dart     yt-dlp version + update (text-only _SettingsPage)
app/android/.../YtDlpBridge.kt    Kotlin bridge: init / info / download / cancel / update
```

## ⚖️ Legal — read this

- **Personal use only.** Only download your own videos, Creative Commons /
  openly-licensed content, or content you have explicit permission for.
- Unauthorized downloading violates YouTube's Terms of Service.
- This project is for private, local use. It is not affiliated with YouTube
  or Google. Sideload-only by design — YouTube downloaders are banned from
  the Play Store, so this app will never be published there.

## 🤝 Contributing

Issues and PRs welcome. Run `flutter analyze && flutter test` before pushing.
For big changes, open an issue first to discuss.

## 📄 License

See [LICENSE](./LICENSE).
