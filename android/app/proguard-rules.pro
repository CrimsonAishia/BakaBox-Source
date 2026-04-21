# Flutter 默认规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 忽略 Play Core 延迟组件（不使用此功能）
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# 保留应用自定义代码（MainActivity 的 APK 安装功能）
-keep class cc.aishia.bakabox.** { *; }

# Gson / JSON 序列化（如果有用到）
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# OkHttp (dio 底层)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# 保留 R 类
-keepclassmembers class **.R$* {
    public static <fields>;
}

# 保留 Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# 保留枚举
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# AndroidX FileProvider（APK 安装功能需要）
-keep class androidx.core.content.FileProvider { *; }

# 保留 MethodChannel 回调
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# 桌面端专属插件（Android 端排除了原生库，忽略相关警告）
-dontwarn com.k0d4black.sherpa_onnx.**
-dontwarn com.mediadevkit.fvp.**
