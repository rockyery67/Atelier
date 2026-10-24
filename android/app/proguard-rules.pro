# Gson persists notification model field names. AtelierClockReceiver reads the
# version-pinned JSON cache to rebase wall times after system clock changes.
-keepattributes Signature,*Annotation*
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.AtelierClockReceiver { *; }
-keep class * extends com.google.gson.reflect.TypeToken
