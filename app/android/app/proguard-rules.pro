# youtubedl-android bundles Python/ffmpeg and uses libraries that rely on
# reflection. R8 must not shrink or rename them, otherwise init crashes
# (e.g. ZipFile/ExtraFieldUtils: "class AsiExtraField is not a concrete class").

# Apache commons-compress: extra-field implementations are instantiated
# reflectively by ExtraFieldUtils static init.
-keep class org.apache.commons.compress.** { *; }
-keepclassmembers class org.apache.commons.compress.** { *; }

# Jackson databind: VideoInfo/VideoFormat/VideoThumbnail models are
# deserialized reflectively from yt-dlp --dump-json output.
-keep class com.fasterxml.jackson.** { *; }
-keep class com.yausername.youtubedl_android.** { *; }
-keepclassmembers class com.yausername.youtubedl_android.** { *; }
-keep class com.yausername.ffmpeg.** { *; }

# These are optional desktop-only references that don't exist on Android
# (Jackson's Java7 support, commons-compress's xz codec). Never hit at runtime.
-dontwarn java.beans.**
-dontwarn org.tukaani.xz.**
-dontwarn org.w3c.dom.bootstrap.**
