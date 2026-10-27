# Flutter 保留规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive / photo_manager 等插件通过反射调用的平台代码由 Flutter 插件自动生成的规则覆盖；
# 如 release 包运行时出现 ClassNotFoundException，可在此追加对应 -keep 规则。

# 未使用 Play Store 延迟组件（deferred components），忽略 Flutter 引擎对其的引用
-dontwarn com.google.android.play.core.**
