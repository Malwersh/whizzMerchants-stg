# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.

# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Uncomment this to preserve the line number information for
# debugging stack traces.
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
-renamesourcefileattribute SourceFile

# Keep Flutter-related classes
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }

# Keep business-specific classes
-keep class com.hadhir.business.** { *; }

# Preserve JSON serialization classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep notification-related classes
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# Preserve native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Network security
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-keepattributes Signature
-keepattributes *Annotation*
