# Proguard / R8 rules for WappTidy Release Packaging

# Flutter engine and plugin wrappers
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WappTidy Kotlin Native Bridge Classes
-keep class com.wapptidy.wapptidy.** { *; }
-keepclassmembers class com.wapptidy.wapptidy.** { *; }

# AndroidX WorkManager (Background Scans & Maintenance)
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

# SQLite3 / Drift native binding preservation
-keep class org.sqlite.** { *; }
-keep class sqlite3.** { *; }
-keep class com.simonbadges.** { *; }

# Kotlin coroutines and annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn java.lang.instrument.**
-dontwarn javax.annotation.**

# Google Play In-App Billing
-keep class com.android.vending.billing.** { *; }

# Android MediaStore reflection warnings
-dontwarn android.provider.MediaStore**
