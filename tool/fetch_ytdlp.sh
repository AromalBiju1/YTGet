#!/usr/bin/env bash
set -euo pipefail
# NOTE: yt-dlp official releases ship NO Android binary.
# Available standalone builds: yt-dlp_linux, yt-dlp_linux_aarch64 (glibc —
# will NOT run on Android's bionic libc), yt-dlp_macos, yt-dlp.exe.
# Android options (to be decided):
#   1. youtubedl-android (Maven, what Seal uses) via Kotlin MethodChannel
#   2. Community android builder (e.g. abdelhakimelmoumen/yt-dlp-android-build)
#      producing a self-extracting Termux-python + .pyz wrapper
#   3. Chaquopy embedded Python + `pip install yt-dlp`
# Until one is chosen, this script only stages the portable pyz for reference.
mkdir -p app/assets/bin/arm64-v8a
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  -o app/assets/bin/arm64-v8a/yt-dlp.pyz
echo "staged portable yt-dlp.pyz (needs a Python runtime on-device — see note above)"
