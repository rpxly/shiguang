# 拾光 (shiguang) — AI 相册

> **版本**: 1.0.0+1  
> **更新日期**: 2026-07-20  
> **定位**: 个人记忆管家 — 基于杂志风模板的照片整理与月刊排版工具  
> **设计风格**: Magazine Minimal + Glassmorphism（杂志极简 + 玻璃拟态）

---

## 一、项目概述

"拾光"是一款 Flutter 移动端应用，通过卡片式整理、杂志模板排版、文案库裂变等能力，帮助用户把散落的照片整理成可分享的月度记忆。核心能力包括：

- 自动扫描本地相册（PhotoManager 分页扫描 + 文件系统兜底）
- 卡片式快速整理（左滑删除 / 右滑收藏 / 上滑保留 / 拖入相簿）
- 6 种杂志模板 + 4 种胶片品牌模拟（柯达/富士/伊尔福/无品牌）
- 内置 170 条精选文案库 + AI 裂变 + 联网抓取（hitokoto）
- 月刊编辑器（模板排版 + 实时预览 + PNG 导出分享）
- 智能筛选与相簿管理
- AI 全局三入口（月刊文案优化 / 文案裂变 / 联网抓取）

---

## 二、技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.22.3 | 跨平台 UI 框架 |
| Dart | 3.4.4 | 编程语言 |
| Provider | ^6.1.1 | 状态管理 |
| Hive | ^2.2.3 | 本地 NoSQL 数据库 |
| photo_manager | ^3.3.0 | 系统相册访问与删除 |
| webview_flutter | ^4.8.0 | 胶片索引页（本地 HTML5 应用） |
| image_picker | ^1.1.2 | 月刊照片选择 |
| http | ^1.2.2 | HTTP 请求（AI API / hitokoto） |
| share_plus | ^10.0.4 | 分享导出 |
| path_provider | ^2.1.5 | 文件路径获取 |

---

## 三、项目结构

```
lib/
├── main.dart                          # 应用入口：LoadingApp 初始化 → MainScreen 5 Tab 导航
├── app_state.dart                     # 全局状态（selectedPhoto / showSettings / dataVersion）
├── theme.dart                         # 完整设计系统（颜色/间距/圆角/阴影/渐变/玻璃拟态/动画）
│
├── components/                        # UI 组件库（11 个）
│   ├── glass_card.dart                # 毛玻璃卡片容器（核心组件，gradient/onTap/shadow）
│   ├── tab_bar.dart                   # 底部 Tab 导航栏（5 Tab：首页/筛选/月刊/文案/胶片）
│   ├── nav_header.dart                # 子页面顶部导航栏（返回 + 标题 + 操作按钮）
│   ├── bottom_blur_bar.dart           # 模态底部面板（圆角 + 把手 + 可选毛玻璃/纯色）
│   ├── app_button.dart                # 统一按钮（primary/secondary/ghost/danger/outline × sm/md/lg × pill/rect/circle）
│   ├── app_chip.dart                  # 统一 chip（selectable/tag/action 三种风格）
│   ├── app_dialog.dart                # 统一对话框（show/confirm/input 三种模式）
│   ├── empty_state.dart               # 空状态视觉（neutral/success/accent 三种语义色调）
│   ├── loading_overlay.dart           # 全屏 Loading 遮罩
│   ├── shimmer_skeleton.dart          # Shimmer 骨架屏（box/list/timeline）
│   └── staggered_fade_in.dart         # 列表项 stagger 淡入上滑动画
│
├── pages/                             # 页面（11 个）
│   ├── home_page.dart                 # [Tab] 首页 — Hero + 统计卡片 + 最近回忆 + 时间线
│   ├── smart_filter_page.dart         # [Tab] 智能筛选 — 分类胶囊 + 照片网格 + 相簿管理
│   ├── monthly_magazine_page.dart     # [Tab] 月刊 — 6 模板 + 胶片模拟 + 导入编辑导出
│   ├── quote_library_page.dart        # [Tab] 文案库 — 分类浏览 + 联网抓取
│   ├── film_index_page.dart           # [Tab] 胶片索引 — WebView 加载本地 HTML5 胶片模拟应用
│   ├── photo_detail_page.dart         # [Push] 照片详情 — 大图 + 元数据 + 相似照片
│   ├── slide_box_page.dart            # [Push] 卡片整理 — 左滑删除/右滑收藏/上滑保留/拖入相簿
│   ├── curated_photos_page.dart       # [Push] 精选照片 — 收藏照片展示
│   ├── cleanup_suggestion_page.dart   # [Push] 清理建议 — 截图分类批量清理
│   ├── settings_page.dart             # [Push] 设置 — 主题 + 应用设置 + 端侧 AI 诊断入口
│   ├── on_device_ai_page.dart         # [Push] 端侧 AI 诊断 — 设备闸门/模型状态/试跑/提示词预览
│   └── watermark_page.dart            # [Push] 水印 — 边框/文字/浮层/相机模式 + EXIF
│
├── models/                            # 数据模型（4 个）
│   ├── photo.dart                     # Photo — 照片（15 字段，含 ML Kit 标签/质量评分/收藏）
│   ├── diary.dart                     # DiaryEntry + WeeklySummary + MonthlyDiary
│   ├── quote.dart                     # Quote — 文案（text/author/source/category）
│   └── album.dart                     # Album — 相簿（id/name/order/coverPath/localAlbumId）
│
├── services/                          # 服务层（12 个）
│   ├── database_service.dart          # DatabaseService — Hive 初始化 + Schema 迁移 + 扫描入口
│   ├── photo_scanner_service.dart     # PhotoScannerService — 分页扫描（200/页）+ 文件系统兜底
│   ├── scene_classifier_service.dart  # SceneClassifier — ML Kit 离线场景识别（标签→中文场景词）
│   ├── monthly_recap_service.dart     # MonthlyRecapService — 规则版月度摘要（只陈述照片事实）
│   ├── on_device_ai_service.dart      # OnDeviceAiService — 端侧 LLM POC 骨架（提示词/闸门/兜底）
│   ├── quote_service.dart             # QuoteService — 170 条内置文案 + 自定义文案管理
│   ├── quote_fetcher_service.dart     # QuoteFetcherService — hitokoto 联网抓取
│   ├── steps_service.dart             # StepsService — Health Connect 月度步数
│   └── image_helper.dart              # LocalImage — 统一图片组件（cacheWidth 自动推导 + LayoutBuilder 兜底）
│
└── repository/
    └── local_repository.dart          # LocalRepository — 5 个 Hive Box 的 CRUD + 相簿管理 + 缓存
```

---

## 四、数据流架构

```
┌─────────────────────────────────────────────────────────────┐
│                       系统相册 (PhotoManager)                 │
└─────────────────────────┬───────────────────────────────────┘
                          │ scanDevicePhotos() — 分页 200/页
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               PhotoScannerService                            │
│   - 权限请求 → PhotoManager 分页扫描 → 兜底文件系统扫描     │
│   - 批量回调 onBatch → 实时写入 DB                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ List<Photo>
                          ▼
┌─────────────────────────────────────────────────────────────┐
│   DatabaseService → LocalRepository (Hive Box × 5)           │
│   - 缓存层: _cachedPhotos (getAllPhotos 零开销)              │
│   - Schema 版本控制 (v2，不兼容时自动清理重建)              │
└─────────────────────────┬───────────────────────────────────┘
                          │ 读取
                          ▼
┌─────────────────────────────────────────────────────────────┐
│   Pages (Provider 或直接调用 Repository)                     │
│   Home → SmartFilter → MonthlyMagazine → SlideBox → ...     │
└─────────────────────────────────────────────────────────────┘
```

**AI 能力（2026-10-27 起为「规则摘要 + 端侧 LLM POC」双轨）**:
1. **规则版月度摘要** — `MonthlyRecapService` — 从照片事实（场景词/地名/人脸/精选/夜间）生成 3 句总结，已接入月刊页「智能摘要」
2. **端侧 LLM（未接线）** — `OnDeviceAiService` — Qwen3-1.7B 端侧叙事的 POC 骨架，`kOnDeviceLlmWired=false` 时全部请求自动走规则版
3. **联网抓取文案** — `QuoteFetcherService` — hitokoto 热句抓取（无 AI 生成）

> 旧的 `AiService`（OpenAI 兼容协议）已整体移除。端侧 AI 的选型与验证结论见
> 《拾光-端侧AI选型与Flutter升级评估.md》《拾光-端侧AI提示词离线验证报告.md》。

---

## 五、导航架构

### 5.1 底部 Tab 栏（5 个主页面）

| Tab | TabType | 页面 | 说明 |
|-----|---------|------|------|
| 首页 | home | HomePage | Hero + 统计卡片 + 最近回忆 + 时间线 |
| 筛选 | filter | SmartFilterPage | 分类胶囊 + 照片网格 + 相簿管理 |
| 月刊 | magazine | MonthlyMagazinePage | 6 模板排版 + 胶片模拟 + 导入导出 |
| 文案 | quotes | QuoteLibraryPage | 分类浏览 + AI 裂变 + 联网抓取 |
| 胶片 | filmIndex | FilmIndexPage | WebView 胶片模拟应用 |

**性能策略**: Tab 页面按需构建 + 懒缓存（`_tabCache.putIfAbsent`），不再使用 IndexedStack 全量保活。

### 5.2 Push 页面（无底部 Tab，有返回按钮）

| 页面 | 入口 | 功能 |
|------|------|------|
| PhotoDetailPage | 点击照片 | 大图浏览（cacheWidth 限内存） + 元数据 + 相似照片 |
| SlideBoxPage | 首页统计卡片 | 卡片式整理（左滑删除/右滑收藏/上滑保留/拖入相簿） |
| SettingsPage | 首页设置按钮 | 主题切换 + 应用设置 + 端侧 AI 诊断 |
| CuratedPhotosPage | 首页精选 | 收藏照片展示 |
| CleanupSuggestionPage | 首页清理建议 | 截图分类批量清理 |
| AiConfigDialog | 设置页 AI 按钮 | API Key / Base URL / 模型配置 |

### 5.3 页面跳转流程

```
HomePage ───→ SmartFilterPage ───→ PhotoDetailPage
    │                                    │
    ├──→ SlideBoxPage                    └──→ SmartFilterPage (返回)
    ├──→ SettingsPage ──→ AiConfigDialog
    ├──→ CuratedPhotosPage
    └──→ CleanupSuggestionPage

MonthlyMagazinePage ───→ AI 文案优化 → 模板编辑 → PNG 导出分享
QuoteLibraryPage ───→ AI 裂变 / 联网抓取
FilmIndexPage ───→ WebView 胶片模拟
```

---

## 六、关键功能模块

### 6.1 照片扫描
- **扫描来源**: 优先 PhotoManager API（系统相册），兜底文件系统扫描
- **分页策略**: 每页 200 张，扫描结果通过 `onBatch` 回调实时写入 DB
- **权限处理**: 相册权限 + MANAGE_EXTERNAL_STORAGE 存储权限
- **强制重扫**: `forceScan: true` 重置完成标志，允许重新扫描

### 6.2 卡片整理（SlideBox）
- **交互**: 左滑删除 / 右滑收藏 / 上滑保留 / 横向拖入相簿
- **性能**: 拖拽阶段使用 Transform.translate + Opacity（即时渲染），动画阶段切换为 AnimatedContainer（平滑过渡）
- **删除队列**: 批量延迟删除，支持撤销

### 6.3 月刊编辑器
- **6 种模板**: 下留白 / 全幅 / 拍立得 / 中线 / 立体相框 / 胶片质感
- **4 种胶片品牌**: 柯达（黄红）/ 富士（绿）/ 伊尔福（黑白）/ 无品牌（纯净）
- **自定义参数**: 内边距 / 外边距 / 圆角 / 图文间距 / 图片比例 / 字体样式
- **模板适配**: 根据图片横竖比例自适应布局尺寸，完整显示不裁剪
- **批量导入**: 照片选择 + 随机文案分配（从文案库抽取，避免重复）+ 实时预览
- **导出**: RepaintBoundary 截图 → PNG 图片 → 系统分享

### 6.4 文案库
- **170 条内置文案**: 哲思/生活/孤独/旅行/爱情/自然/时间/网易云/小红书 9 个分类
- **AI 裂变**: 基于选中文案，AI 生成一批同主题新文案
- **联网抓取**: hitokoto API 并发抓取 5 条 + AI 生成 5 条（需启用 AI）
- **自动抓取**: 设置页可开启「自动联网抓取文案」

### 6.5 智能筛选与相簿
- **分类筛选**: 全部/已整理/未整理 + 按分类胶囊筛选
- **相簿管理**: 创建/重命名/删除/排序 + 自动同步本地相簿
- **照片操作**: 点击查看详情 / 长按多选 / 拖入相簿

---

## 七、设计系统

完整实现在 [theme.dart](file:///f:/daima/ai-album/lib/theme.dart) 中。

| 类别 | 内容 |
|------|------|
| **颜色** | 16 个亮色 Token + 16 个暗色 Token + 4 个状态色 + 4 个强调色 |
| **玻璃拟态** | GlassColors（bg/bgHeavy/border/shadow/inset 各 2 套） |
| **渐变** | 5 个预设（accent/accentSoft/sunset/ocean/success） |
| **间距** | 12 级（4px ~ 96px） |
| **圆角** | 6 级（4px ~ 9999px） |
| **字号** | 8 级（12px ~ 48px） |
| **字重** | 5 级（Light ~ Bold） |
| **行高** | 4 级（tight/snug/normal/relaxed） |
| **阴影** | 3 级（sm/md/lg 各 2 套） |
| **过渡** | 3 级（150ms/250ms/400ms） + shimmer（800ms） |
| **主题** | lightTheme + darkTheme 完整 ThemeData |
| **扩展** | ThemeContext（BuildContext 颜色访问）+ WidgetPad + GapExtension |

---

## 八、Hive 数据库 Schema（5 个 Box）

| Box 名称 | 数据类型 | 用途 |
|----------|---------|------|
| photos | Photo | 照片数据 |
| diary_entries | DiaryEntry | 日记条目 |
| monthly_diaries | MonthlyDiary | 月度日记（key: `${year}_${month}`） |
| quotes | Quote | 自定义文案（内置文案不入库） |
| general_settings | 混合 | 通用设置 + 相簿列表 + 月刊页面数据 |

**Schema 版本控制**: `general_settings` 中记录 `schema_version`，当前版本 2。版本升级时自动清理不兼容的 box（photos/diary_entries/monthly_diaries/quotes）并重建。

**general_settings 存储内容**:
- `themeMode` / `autoScan` / `skipDeleteConfirm` / `autoFetchQuotes`
- `aiApiKey` / `aiBaseUrl` / `aiModel` / `aiEnabled`
- `albums_list`（相簿列表 JSON）/ `album_photos_${albumId}`（相簿照片 ID 列表）
- `magazine_${year}_${month}`（月刊照片 ID）/ `magazine_pages_${year}_${month}`（月刊页面 JSON）/ `magazine_meta_${year}_${month}`（月刊元数据）
- `lastQuoteFetchTime`

---

## 九、性能优化

### 9.1 图片加载优化
- **cacheWidth 自动推导**: LocalImage 组件按显示尺寸 × 1.5 计算解码尺寸，避免原图完整解码
- **LayoutBuilder 兜底**: 当 width/height 为 null 或 infinity 时，用父约束推导 cacheWidth
- **大图查看器**: photo_detail_page 显式传入 cacheWidth = screenWidth × devicePixelRatio
- **缩略图网格**: cleanup_suggestion_page GridView 按 3 列宽度计算 cacheWidth

### 9.2 页面构建优化
- **Tab 懒缓存**: main.dart 使用 `_tabCache.putIfAbsent` 按需构建 Tab 页面，替代 IndexedStack 全量保活
- **getter 缓存**: smart_filter_page / quote_library_page / home_page 将 build 中重复计算的 getter 改为 `_loadData` 时预计算缓存字段
- **DB 预计算**: smart_filter_page 相簿照片数量从 build 中同步查 DB 改为 `_cachedAlbumPhotoCounts` map
- **单次遍历**: home_page `_loadData` 将 3 次 `where()` 合并为 1 次 `for` 循环

### 9.3 重绘优化
- **RepaintBoundary**: Hero 区、时间线分组、精选照片卡片、SlideBox 图片卡片
- **拖拽分叉**: SlideBox 拖拽阶段用 Transform.translate + Opacity（跳过隐式动画），动画阶段切回 AnimatedContainer
- **Timer 轻量刷新**: home_page 扫描期间仅查总数，无变化不 setState

### 9.4 内存优化
- **照片删除同步**: 删除照片时同时删除原图文件 + 缩略图文件 + DB 记录，确保数据同步
- **文案池缓存**: monthly_magazine_page `_randomCaption` 懒缓存 `QuoteService().allQuotes`，避免每次调用重建 170 条列表

---

## 十、构建说明

### 开发环境
- Flutter SDK: 项目内嵌 `f:\daima\ai-album\flutter\flutter`
- Dart SDK: 跟随 Flutter SDK（3.4.4）
- Android SDK: 通过 local.properties 配置
- JDK: 17（Gradle Kotlin 编译目标）

### 构建命令
```bash
# Release APK
flutter build apk --release

# Debug APK
flutter build apk --debug
```

### 生成 Hive 适配器
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 静态分析
```bash
flutter analyze
```
