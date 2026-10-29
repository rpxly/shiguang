# 拾光 · Shiguang — AI 相册

> **拾光**是你的个人记忆管家 — 卡片式快速整理、杂志模板月刊排版、170 条精选文案、胶片索引与杂志风水印。你的照片，从不需要被上传。

**🌐 官网**：<https://rpxly.github.io/shiguang/>
**📥 下载 APK**：<https://rpxly.github.io/shiguang/apks/shiguang-v1.1.0-release.apk>（v1.1.0 · Android 8.0+ · arm64）

## 核心能力

- **卡片式快速整理** — 左滑删除 / 右滑收藏 / 上滑保留 / 拖入相簿，批量延迟删除可撤销
- **按月份整理与相簿** — 未整理照片按月归组、逐月清零；相簿创建 / 重命名 / 排序
- **月刊编辑器** — 6 种杂志模板，「时光线」一键成刊，导出 PNG 分享
- **智能摘要** — 心情 / 天气 / 步数 / 出行事实汇总，只陈述照片事实
- **文案库** — 170 条内置精选文案（9 大分类）+ 联网热句抓取
- **胶片索引与胶片质感** — 按月浏览全部照片；柯达 / 富士 / 伊尔福 / 无品牌 4 种模拟
- **杂志风水印** — 相机时间地点水印、杂志风边框，EXIF 完整保留

## 隐私

无账号、无云端上传。照片与整理记录全部保存在本机（Hive 数据库），场景识别由 ML Kit 在设备上离线完成，唯一的联网请求是获取一句话文案（hitokoto）。

## 技术栈

Flutter 3.22 · Dart 3.4 · Provider · Hive · photo_manager · ML Kit · webview_flutter

## 开发

```bash
flutter pub get
flutter analyze        # 静态检查
flutter build apk --release
```

## 仓库结构

```
lib/          App 源码（pages / components / services / models）
android/      Android 工程
windows/      Windows 桌面端工程
assets/       静态资源
index.html    GitHub Pages 官网（站点源 = 仓库根目录）
apks/         官网下载用的发布 APK
```

> 本仓库同时是官网的 Pages 源（Settings → Pages → Deploy from a branch → master / root）。
