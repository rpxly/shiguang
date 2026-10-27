# Tasks

- [x] Task 1: 扫描状态广播与主界面刷新（P0）
  - [x] SubTask 1.1: `DatabaseService` 改为 `ChangeNotifier`，新增 `scanTotal` 与批次节流通知（≤1 次/500ms），扫描开始/完成/异常均通知
  - [x] SubTask 1.2: `main.dart` 用 `ChangeNotifierProvider<DatabaseService>.value` 包裹应用；`MainScreen` 订阅服务，移除 `_tabCache`
  - [x] SubTask 1.3: 惰性 Offstage Tab 容器：仅访问过的 Tab 创建页面，未访问用 `SizedBox.shrink`，已访问用 `Offstage + TickerMode` 保活；实时传递扫描状态
  - [x] SubTask 1.4: `HomePage` 删除 5 秒轮询 Timer，改为依赖 widget 属性变化刷新；`getAllPhotos()` 排序前先复制
  - [x] SubTask 1.5: `SmartFilterPage` 接收扫描状态，扫描开始/完成自动重载；扫描中空列表显示骨架屏

- [x] Task 2: 图片解码与缩略图管线（P0）
  - [x] SubTask 2.1: `image_helper.dart` 新增纯函数 `resolveCacheSize`，按 DPR 计算并限制 2048px；asset/file 路径统一使用
  - [x] SubTask 2.2: `PhotoScannerService` 通过 `thumbnailDataWithSize(256×256, quality 80)` 生成缩略图写入 `<临时目录>/thumbs/<safeId>.jpg`
  - [x] SubTask 2.3: 已存在但缩略图仍指向原图的记录在扫描时补生成；不改变 Hive schema
  - [x] SubTask 2.4: `LocalRepository` 删除照片/批量删除时同步删除缩略图文件
  - [x] SubTask 2.5: 首页、筛选页等调用点移除写死解码尺寸，交由组件按 DPR 推导

- [x] Task 3: 扫描增量与并发（P1）
  - [x] SubTask 3.1: 扫描前构建 id→Photo Map，跳过缩略图完整的已有照片；强制重扫刷新元数据但不重复记录
  - [x] SubTask 3.2: 元数据抓取 + 缩略图生成按 4 路并发
  - [x] SubTask 3.3: 保留 200/页分页与 onBatch 实时入库，扫描通知节流

- [x] Task 4: 数据查询热路径（P1，依赖 Task 2 与 Task 3 的仓库改动）
  - [x] SubTask 4.1: `smart_filter_page._buildMonthGroups` 改为 Map 单次遍历分组
  - [x] SubTask 4.2: 新增 `LocalRepository.getAlbumPhotosMap()` / `getAlbumPhotoCounts()`，用 id→Photo Map 完成相簿照片查询与计数；替换 `getAlbumPhotos` 的嵌套 `where`
  - [x] SubTask 4.3: `photo_detail_page._loadData` 相似照片选取改用 id Set，避免 `List.contains` 的 O(n²)
  - [x] SubTask 4.4: 抽出 `groupPhotosByMonth` 纯函数供页面与测试共用

- [x] Task 5: 拆分月刊页（P1）
  - [x] SubTask 5.1: 模型与枚举迁到 `lib/pages/monthly/magazine_models.dart`
  - [x] SubTask 5.2: 模板渲染迁到 `lib/pages/monthly/magazine_templates.dart`
  - [x] SubTask 5.3: 导入/分享/选择面板迁到 `lib/pages/monthly/magazine_sheets.dart`
  - [x] SubTask 5.4: A4 排版迁到 `magazine_a4.dart`、时间线迁到 `magazine_timeline.dart`、编辑器迁到 `magazine_editor.dart`；各文件 ≤900 行

- [x] Task 6: UI/可访问性细节（P2，依赖 Task 1）
  - [x] SubTask 6.1: 扫描中筛选页骨架屏与「正在扫描」文案
  - [x] SubTask 6.2: 首页头部实时扫描进度
  - [x] SubTask 6.3: 底部 Tab 与主要卡片补 `Semantics(button: true, selected/label)`，触控区域 ≥48dp
  - [x] SubTask 6.4: 统一相册/照片打开与长按的触感反馈，避免重复触发

- [x] Task 7: 测试与静态检查（依赖 Task 1–6）
  - [x] SubTask 7.1: 修复 `test/widget_test.dart` 对已删除 `showSlideBox` 的引用
  - [x] SubTask 7.2: 新增月份分组、DPR 解码尺寸、相簿查询/计数测试
  - [x] SubTask 7.3: 执行 `dart analyze lib test`，0 error / 0 warning（57 条 info）
  - [x] SubTask 7.4: 执行 `flutter test`，9 个测试全部通过

- [ ] Task 8: 构建与设备验证（依赖 Task 7）
  - [ ] SubTask 8.1: `flutter build apk --debug` 构建成功
  - [ ] SubTask 8.2: 如已连接模拟器/真机：`adb install` 安装，授予相册权限，验证首页扫描进度、五个 Tab 切换、筛选页骨架屏、月刊页模板切换
  - [ ] SubTask 8.3: 采集验证证据：关键页面截图、`adb logcat` FATAL 检查、gfxinfo 或启动耗时记录；无设备时记录为「待设备验证」

# Task Dependencies

- Task 1、Task 2、Task 5 相互独立，可并行
- Task 3 依赖 Task 2（扫描管线同一文件）
- Task 4 依赖 Task 2（仓库接口）与 Task 3（扫描后数据一致性）
- Task 6 依赖 Task 1（实时状态与 Tab 容器）
- Task 7 依赖 Task 1–6 全部完成
- Task 8 依赖 Task 7
