# Proguard / R8 rules for WazApp release builds

# Flutter engine and plugin wrappers
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WazApp Kotlin native bridge (channel handlers are invoked reflectively by Flutter)
-keep class com.webappypie.wazapp.** { *; }

# SQLite3 / Drift native binding preservation
-keep class org.sqlite.** { *; }
-keep class sqlite3.** { *; }

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn java.lang.instrument.**
-dontwarn javax.annotation.**

# Flutter engine references Play Core deferred-components classes; WazApp does not use deferred components.
-dontwarn com.google.android.play.core.**
