# ProGuard / R8 keep 规则（release 构建启用 R8 时生效）。
#
# FFmpegKit（ffmpeg_kit_flutter_new_*）保留规则：
# AbiDetect.getNativeCpuAbi 等方法仅由 native 库的 JNI_OnLoad 反射注册，
# R8 静态分析看不到任何 Java/Kotlin 调用方，会将其裁剪/改名。一旦被裁，
# native 侧 RegisterNatives 失败 → JNI_OnLoad 返回非法版本（Bad JNI version）
# → FFmpegKit 静态初始化抛 java.lang.Error → GeneratedPluginRegistrant 整体
# 注册失败 → 所有插件（shared_preferences/path_provider 等）不可用 → main()
# 首个插件调用即失败、runApp 永不执行 → App 永远卡在启动 splash。
#
# 该插件 AAR 把 keep 规则写成 proguardFiles（仅作用于库自身）而非
# consumerProguardFiles，不会传播到宿主 app，必须在此显式声明。
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# 通用：保留所有 native 方法及其所在类的成员名，避免 JNI 注册错配。
-keepclasseswithmembernames class * {
    native <methods>;
}
