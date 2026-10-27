# 拾光 App 去 AI 化与整体重设计 Spec

## Why

「拾光」当前内置一套 OpenAI 兼容的 AI 接口（文案优化、文案裂变、AI 生成文案），用户决定全面移除 AI 能力；联网文案抓取（hitokoto）保留并继续对接文案库；同时借此机会重做信息架构（5 Tab 收敛为 3 Tab）与视觉语言（暗色玻璃拟态、奢华精致），并裁剪冗余功能。

## What Changes

- **移除 AI 接口与功能（BREAKING）**：删除 `AiService`、AI 配置弹窗、设置页「AI 配置」分区、月刊「AI 优化文案」按钮、文案库「AI 裂变」入口；仓库层 AI 配置键（aiApiKey/aiBaseUrl/aiModel/aiEnabled）一并移除。
- **联网文案保留并去 AI 化**：`QuoteFetcherService` 仅保留 hitokoto 在线抓取并入库文案库，删除其中 AI 生成部分；保留「联网自动获取文案」设置项。
- **整理状态改为手动标记驱动**：`Photo.aiSuggestion` 字段语义重命名为「用户手动整理标记」（仅在滑动整理页标记后视为已整理），首页统计、筛选页分组、详情页标识全部改用该语义；Hive 字段序号不变，旧数据透明兼容。
- **信息架构收敛为 3 Tab**：`首页 / 整理 / 月刊`。
  - 首页：扫描进度、统计概览、最近回忆、精选/清理入口、设置入口（右上角）、工具入口（胶片索引 WebView）。
  - 整理：合并原「筛选」页的未整理（月份分组 → 滑动整理）与相簿两个子 Tab，并整合「清理建议」「精选」入口。
  - 月刊：月刊编辑器内置「文案选择面板」（内置 + 自建 + hitokoto 联网文案），替代独立「文案」Tab。
- **文案库本地化 + 联网补充**：保留内置文案、用户自建文案与 hitokoto 联网文案入库；文案库页从底部 Tab 移除，改造为月刊编辑器内的选文案面板（含「联网获取」入口）；保留用户新建/删除文案能力。
- **视觉重设计**：以暗色玻璃拟态为基准重塑 `theme.dart` 设计令牌（配色、渐变、字体层级、圆角、阴影、间距），重做底部 TabBar、卡片、空态、按钮与设置页，风格目标：奢华精致、克制留白、层级清晰（KPI → 内容 → 列表）。
- **裁剪**：删除 `ai_config_dialog.dart`、`ai_service.dart`；`http` 依赖保留（hitokoto 联网文案使用）。

## Impact

- 影响能力：导航与信息架构、首页、整理（原筛选）、月刊编辑、文案库、设置、照片数据模型语义、视觉体系
- 影响代码：
  - 删除：`lib/services/ai_service.dart`、`lib/pages/ai_config_dialog.dart`
  - 重构：`lib/main.dart`（3 Tab + 入口调整）、`lib/components/tab_bar.dart`、`lib/pages/home_page.dart`、`lib/pages/smart_filter_page.dart` → `lib/pages/organize_page.dart`、`lib/pages/quote_library_page.dart` → 月刊选文案面板、`lib/pages/settings_page.dart`、`lib/services/quote_fetcher_service.dart`（去 AI 化，仅保留 hitokoto）
  - 修改：`lib/models/photo.dart`（+重新生成 `photo.g.dart`）、`lib/pages/slide_box_page.dart`、`lib/pages/photo_detail_page.dart`、`lib/pages/monthly_magazine_page.dart`、`lib/pages/monthly/magazine_sheets.dart`、`lib/pages/cleanup_suggestion_page.dart`、`lib/pages/curated_photos_page.dart`、`lib/repository/local_repository.dart`、`lib/theme.dart`、`lib/services/quote_service.dart`
- 数据兼容：Hive `schema_version` 保持 2，`Photo` 字段序号不变（仅 Dart 侧属性改名 + 注释语义更新），旧数据无需迁移；AI 配置键移除后旧值残留于 Box 中无害，不做清理。

## ADDED Requirements

### Requirement: 三 Tab 信息架构
系统 SHALL 提供「首页 / 整理 / 月刊」三个底部 Tab；设置页通过首页右上角入口进入；胶片索引工具通过首页工具入口进入；Tab 保持「首次访问创建 + Offstage 保活」行为。

#### Scenario: 启动后默认首页
- **WHEN** 应用启动完成
- **THEN** 底部仅显示 3 个 Tab，默认选中首页，未访问 Tab 不初始化

#### Scenario: 进入设置
- **WHEN** 用户点击首页右上角设置图标
- **THEN** 打开设置页，返回后回到首页且首页状态保留

#### Scenario: 进入胶片索引工具
- **WHEN** 用户点击首页工具入口
- **THEN** 打开胶片索引页（WebView），返回后回到首页

### Requirement: 整理页三合⼀
系统 SHALL 在「整理」Tab 内提供「未整理 / 相簿」两个子页签，并提供「清理建议」「精选」入口卡片；「未整理」分组依据用户手动整理标记（见「手动整理标记」需求）。

#### Scenario: 未整理子页签
- **WHEN** 用户打开整理 Tab 的「未整理」
- **THEN** 按月份分组展示未标记照片，点击分组进入滑动整理页

#### Scenario: 相簿子页签
- **WHEN** 用户切换到「相簿」
- **THEN** 展示相簿列表与照片数，支持新建相簿与同步本地相簿

#### Scenario: 清理与精选入口
- **WHEN** 用户在整理 Tab 点击「清理建议」或「精选」
- **THEN** 分别进入清理建议页 / 精选页，返回后整理页状态保留

### Requirement: 手动整理标记
系统 SHALL 以「用户是否在滑动整理页标记过该照片」作为已整理的唯一判据；`Photo` 模型字段更名为 `userMark`（`''`=未整理，`'keep'`=已整理），首页统计、整理页分组、详情页、滑动整理页统一使用该字段。

#### Scenario: 滑动整理标记
- **WHEN** 用户在滑动整理页对一张照片执行「保留」
- **THEN** 该照片 `userMark` 置为 `'keep'`，首页已整理数与整理页分组即时更新

#### Scenario: 旧数据兼容
- **WHEN** 存在旧版本写入的 `aiSuggestion='keep'` 记录
- **THEN** 升级后该记录仍被判定为已整理，不丢失状态

### Requirement: 月刊内置文案选择
系统 SHALL 在月刊编辑器的文案编辑入口提供「文案选择面板」，展示内置文案、用户自建文案与 hitokoto 联网文案（支持按分类筛选、搜索），选中即填入；面板提供「联网获取」入口抓取 hitokoto 文案入库；保留用户新建与删除自建文案的能力；不提供任何 AI 生成/优化入口。

#### Scenario: 从月刊选择文案
- **WHEN** 用户在月刊编辑页点击文案输入区域的「选文案」
- **THEN** 弹出文案面板，选中一条后填入当前文案输入框

#### Scenario: 联网获取文案
- **WHEN** 用户在文案面板点击「联网获取」
- **THEN** 从 hitokoto 抓取若干条文案去重后入库并展示在面板中；网络失败时给出提示且不影响已有文案

#### Scenario: 新建自建文案
- **WHEN** 用户在文案面板点击「新建」并输入内容保存
- **THEN** 文案持久化到本地，立即可在面板中选中

### Requirement: 设置页精简
系统 SHALL 在设置页仅保留「外观（主题模式）」与「应用（自动扫描、联网自动获取文案、版本信息）」两个分区；不再出现任何 AI、API Key 相关入口。

#### Scenario: 打开设置页
- **WHEN** 用户进入设置页
- **THEN** 页面仅包含外观与应用两个分区，无 AI 配置项；「联网自动获取文案」开关可正常读写

### Requirement: 视觉体系重设计
系统 SHALL 以暗色玻璃拟态为默认视觉（保留浅色模式可用），重塑设计令牌：配色（深色基底 + 单一强调色 + 渐变高光）、字体层级、圆角、阴影、间距；底部 TabBar、卡片、按钮、空态、骨架屏统一应用新令牌。

#### Scenario: 暗色模式主界面
- **WHEN** 系统或用户选择深色模式
- **THEN** 各页面呈现深色玻璃质感背景、渐变强调色、清晰信息层级（统计 KPI → 内容区 → 列表），无视觉突兀元素

#### Scenario: 浅色模式不回归
- **WHEN** 切换到浅色模式
- **THEN** 所有页面文本对比度可读、无未适配的硬编码深色

## MODIFIED Requirements

### Requirement: 首页
首页从「5 Tab 之一」改为 3 Tab 之首，新增右上角设置入口与工具入口（胶片索引），保留扫描进度、统计、最近回忆；统计口径改用 `userMark`；视觉应用新设计令牌。

### Requirement: 月刊编辑器
月刊页移除「AI 优化文案」按钮，文案编辑入口接入本地文案选择面板；模板、胶片品牌、导入照片、A4 导出、时间线等既有能力保持不变。

### Requirement: 照片数据模型
`Photo.aiSuggestion` 更名为 `userMark` 并更新注释语义（HiveField(14) 序号不变），重新生成 Hive adapter；所有读写点同步更名。

### Requirement: 仓库配置项
`LocalRepository` 移除 `getAiApiKey/setAiApiKey/getAiBaseUrl/setAiBaseUrl/getAiModel/setAiModel/getAiEnabled/setAiEnabled`；保留 `getAutoFetchQuotes/setAutoFetchQuotes`（hitokoto 联网文案开关）与主题、自动扫描等其余配置。

## REMOVED Requirements

### Requirement: AI 接口与配置
**Reason**: 产品定位调整，去除外部 AI 依赖与配置负担。
**Migration**: 删除 `AiService`、`AiConfigDialog` 及设置页 AI 分区；`main.dart` 不再初始化 AI 服务；仓库层 AI 配置键移除，旧残留键值不清理、不读取。

### Requirement: AI 文案裂变与 AI 生成文案
**Reason**: 文案裂变与 AI 生成文案依赖 AI 接口，随 AI 能力一并移除。
**Migration**: 删除文案库 AI 裂变按钮与 `QuoteFetcherService` 中的 AI 生成部分；hitokoto 联网抓取保留。

### Requirement: 独立文案 Tab
**Reason**: 文案消费能力集中在月刊编辑，独立 Tab 造成导航冗余。
**Migration**: 底部「文案」Tab 移除，文案库改造为月刊编辑器内的选文案面板；用户自建文案与已抓取的联网文案数据（Hive Quote Box）保留不变。
