# ─────────────────────────────────────────────────────────────────────────────
# Keep rules for release (R8/ProGuard) builds.
#
# flutter_local_notifications persists scheduled notifications with Gson. R8
# strips the generic type signatures Gson's TypeToken needs, which crashes
# loadScheduledNotifications() in release with:
#   "TypeToken must be created with a type argument".
# Preserving Signature/annotations + the Gson & plugin classes fixes it.
# ─────────────────────────────────────────────────────────────────────────────

# Preserve generic signatures and annotations (required by Gson TypeToken).
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses, EnclosingMethod

# Gson
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.gson.**

# flutter_local_notifications (Gson-serialised model classes)
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.**
