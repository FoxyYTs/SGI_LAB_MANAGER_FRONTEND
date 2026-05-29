# ── App principal — conservar Activity y clases propias ──────────────────────
# R8 en modo release puede eliminar clases del paquete propio si no están
# referenciadas directamente en código Java/Kotlin (solo en AndroidManifest).
-keep class com.poli.sgi.labmanager.** { *; }

# ── Flutter engine — clases cargadas por reflexión ───────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── flutter_secure_storage ────────────────────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Tink: cifrado subyacente de EncryptedSharedPreferences.
# R8 elimina estas clases porque se cargan por reflexión → NoClassDefFoundError en runtime.
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# androidx.security.crypto: requerido por EncryptedSharedPreferences
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ── sqflite ───────────────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── connectivity_plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ── file_picker ───────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ── url_launcher ──────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ── Kotlin / Flutter general ──────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**
