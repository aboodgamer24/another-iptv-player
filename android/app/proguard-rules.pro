# ── Flutter ────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.**

# ── media_kit / libmpv ────────────────────────────────────────────────────
-keep class com.alexmercerind.** { *; }
-keep class media_kit.** { *; }
-dontwarn com.alexmercerind.**

# ── audio_service ─────────────────────────────────────────────────────────
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# ── just_audio ────────────────────────────────────────────────────────────
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# ── sqlite3 / drift ───────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-keep class io.requery.android.database.** { *; }
-dontwarn com.tekartik.sqflite.**

# ── connectivity_plus ─────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ── package_info_plus ─────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# ── file_picker ───────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ── wakelock_plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# ── url_launcher ──────────────────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ── General Android / JNI safety ──────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class * implements java.io.Serializable { *; }
-keep class * implements android.os.Parcelable { *; }
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ── Kotlin ────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
