# Tasks

- [x] Task 1: 移除 AI 服务与配置链路：删除 `lib/services/ai_service.dart`、`lib/pages/ai_config_dialog.dart`；设置页移除「AI 配置」分区（保留「联网自动获取文案」开关）；`main.dart` 移除 `AiService().init`；`LocalRepository` 移除全部 AI 配置键（保留 autoFetchQuotes）；月刊页与 `magazine_sheets.dart` 移除 AI 优化文案按钮；文案库页移除 AI 裂变入口。
  - [x] SubTask 1.1: 删除 ai_service.dart、ai_config_dialog.dart 并清理所有 import 引用
  - [x] SubTask 1.2: 设置页移除「AI 配置」分区（保留联网自动获取文案开关）
  - [x] SubTask 1.3: `LocalRepository` 移除 AI 配置键（保留 autoFetchQuotes）
  - [x] SubTask 1.4: 月刊页、magazine_sheets、文案库页移除 AI 调用入口
- [x] Task 2: 联网文案服务去 AI 化：`quote_fetcher_service.dart` 删除 AI 生成部分与 `ai_service` 引用，仅保留 hitokoto 在线抓取入库；`quote_library_page.dart` 移除 AI 裂变与 AI 相关提示；`http` 依赖保留。
  - [x] SubTask 2.1: quote_fetcher_service 删除 AI 生成段（保留 hitokoto 抓取与去重入库）
  - [x] SubTask 2.2: 文案库页移除 AI 裂变按钮与 AiService 引用
- [x] Task 3: Photo 模型语义重命名：`aiSuggestion` → `userMark`（HiveField(14) 不变），更新注释语义为「用户手动整理标记」；重新生成 `photo.g.dart`；替换 home_page、smart_filter_page、photo_detail_page、slide_box_page、cleanup_suggestion_page、curated_photos_page、photo_grouping 等全部读写点。
  - [x] SubTask 3.1: 修改 photo.dart 并运行 build_runner 重新生成 adapter
  - [x] SubTask 3.2: 全链路替换读写点并更新注释
- [x] Task 4: 信息架构重构为 3 Tab：`tab_bar.dart` 改为「首页/整理/月刊」；`main.dart` 调整 Tab 构建与入口路由（设置、胶片索引改为首页入口）；新建 `lib/pages/organize_page.dart`（未整理/相簿双子 Tab + 清理建议/精选入口卡片）取代 `smart_filter_page.dart`；首页新增右上角设置入口与工具入口。
  - [x] SubTask 4.1: tab_bar.dart 收敛为 3 Tab 并更新图标文案
  - [x] SubTask 4.2: 新建 organize_page.dart（基于 smart_filter_page 改造，合入清理/精选入口）
  - [x] SubTask 4.3: main.dart 路由调整（3 Tab + AppState 入口）
  - [x] SubTask 4.4: home_page 新增设置入口与工具入口（胶片索引）
- [x] Task 5: 文案库改造为月刊选文案面板：`quote_library_page.dart` 重构为 `lib/pages/monthly/quote_picker_sheet.dart` 面板（内置 + 自建 + hitokoto 联网文案，分类筛选/搜索/新建/删除/联网获取），从月刊编辑文案入口唤起；`quote_service.dart` 保留本地能力；「联网自动获取文案」设置生效于面板打开时；底部「文案」Tab 移除。
  - [x] SubTask 5.1: 新建 quote_picker_sheet.dart 面板（含联网获取入口）
  - [x] SubTask 5.2: 月刊编辑器接入「选文案」入口
  - [x] SubTask 5.3: 移除独立文案 Tab 与原页面文件
- [x] Task 6: 视觉体系重设计：重塑 `theme.dart` 设计令牌（暗色玻璃拟态基准、奢华精致：配色/渐变/字体层级/圆角/阴影/间距）；应用到底部 TabBar、卡片、按钮、空态、骨架屏、设置页；浅色模式可用性回归。
  - [x] SubTask 6.1: theme.dart 令牌重塑
  - [x] SubTask 6.2: TabBar 与公共组件（glass_card/app_button/empty_state/shimmer）应用新令牌
  - [x] SubTask 6.3: 首页、整理页、月刊页、设置页应用新视觉
  - [x] SubTask 6.4: 浅色模式对比度与适配回归
- [x] Task 7: 测试与静态检查：修复/更新失效测试，新增 userMark 分组与文案面板相关单测；`flutter analyze` 0 error，`flutter test` 全部通过。
- [x] Task 8: 构建与设备验证：通过 Android Studio（JAVA_HOME=C:\Users\haocheng11\.jdks\jbr-21.0.11）构建 debug APK 并安装到真机，验证 3 Tab 切换、滑动整理标记、月刊选文案、设置页无 AI 项、胶片索引入口可用。

# Task Dependencies

- [Task 2] depends on [Task 1]
- [Task 4] depends on [Task 3]
- [Task 5] depends on [Task 1]
- [Task 6] depends on [Task 4, Task 5]
- [Task 7] depends on [Task 1~6]
- [Task 8] depends on [Task 7]
- [Task 1、3 可并行；Task 4、5 在 3 后可并行]
