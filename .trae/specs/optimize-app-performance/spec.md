# 拾光 App 性能 / 结构 / UI 优化 Spec

## Why

「拾光」面向本机数千张照片的扫描、整理与月刊排版。当前实现有四个可量化的问题：

1. **扫描状态不刷新（功能缺陷）**：`main.dart` 用 `_tabCache.putIfAbsent` 缓存 Tab 的 Widget 实例，`isScanning / scannedCount / scanningComplete` 只在首次构建时传入，扫描进度与结果永远不会回传到首页；同时 Tab 切换会销毁页面 Element，滚动位置与筛选状态丢失。
2. **图片解码不匹配屏幕**：`LocalImage` 固定按逻辑尺寸 ×1.5 计算 `cacheWidth`，未考虑 `devicePixelRatio`。3x 屏幕上 72dp 缩略图按 108px 解码，明显模糊；1x 设备则过解码。相簿封面（44dp）甚至完全未限制解码尺寸。
3. **扫描吞吐低**：`_entityToPhoto` 对每张照片串行 `await entity.file` + `File.length()`，且把原图路径同时当作缩略图路径，列表每次都要解码整张原图；重复扫描也不跳过已入库照片。
4. **结构失衡**：`monthly_magazine_page.dart` 单文件 2924 行，模板渲染、导入/分享面板、A4 排版、时间线全部耦合；`test/widget_test.dart` 引用已删除的 `showSlideBox`，`flutter test` 当前无法编译通过。

## What Changes

- **扫描状态改为可监听**：`DatabaseService` 作为 `ChangeNotifier` 广播扫描批次/完成/数据变更，主界面订阅后即时刷新。
- **导航改为惰性保活**：移除 `_tabCache`，改用「首次访问才创建 + Offstage 保活」的 Tab 容器，既保留页面状态又不重建全部页面。
- **缩略图管线**：扫描期用 `AssetEntity.thumbnailDataWithSize` 生成 256px 缩略图写入缓存目录，`Photo.thumbnailPath` 指向缩略图；删除照片时同步清理；旧记录在下次扫描时补生成。
- **解码尺寸 DPR 感知**：`LocalImage` 按 `逻辑尺寸 × devicePixelRatio` 计算解码尺寸并设上限，所有图片调用点统一受益。
- **扫描增量 + 有界并发**：跳过已入库照片，仅处理新增/缺缩略图的照片；相册元数据与缩略图生成按 4 路并发执行。
- **热路径去平方复杂度**：月份分组、相簿照片查询/计数、相似照片选取改为 Map/Set 单次遍历。
- **拆分月刊页**：模型、模板渲染、底部面板、A4 排版拆到 `lib/pages/monthly/` 下的独立文件，页面只保留状态编排与持久化。
- **UI/UX 补齐**：扫描期间筛选页显示骨架屏而非「已整理完成」；Tab 与卡片补语义标签、触控区域不小于 48dp；首页展示实时扫描进度。
- **测试与验证**：修复失效单测，新增分组/解码尺寸/相簿查询单元测试；`flutter analyze` 与 `flutter test` 归零；构建 debug APK 并在模拟器可用时执行 adb 流程验证。

## Impact

- 影响能力：照片扫描、首页、智能筛选、照片详情、月刊编辑、图片加载、底部导航
- 影响代码：
  - `lib/services/database_service.dart`、`lib/services/photo_scanner_service.dart`、`lib/services/image_helper.dart`
  - `lib/repository/local_repository.dart`、`lib/models/photo.dart`（仅缩略图路径语义）
  - `lib/main.dart`、`lib/pages/home_page.dart`、`lib/pages/smart_filter_page.dart`、`lib/pages/photo_detail_page.dart`
  - `lib/pages/monthly_magazine_page.dart` → 拆分为 `lib/pages/monthly/*`
  - `lib/components/tab_bar.dart`、`test/widget_test.dart`、新增 `test/*`
- 数据兼容：不新增/不删除 Hive Box，`schema_version` 保持 2；`thumbnailPath` 语义从「原图路径」变为「缩略图路径」，旧数据在扫描时自动补齐。

## ADDED Requirements

### Requirement: 扫描状态实时同步
系统 SHALL 在扫描开始、每批入库、扫描完成时通知订阅者，使首页与筛选页无需手动刷新即可展示最新进度与数据。

#### Scenario: 首次扫描时首页显示进度
- **WHEN** 应用启动并开始扫描，且首页正在显示
- **THEN** 首页统计数字与扫描进度随批次入库持续更新，扫描完成后显示最终数量

#### Scenario: 扫描期间切换到筛选页
- **WHEN** 扫描尚未完成时用户打开「筛选」Tab
- **THEN** 页面显示骨架屏，扫描完成后自动刷新为真实照片列表

#### Scenario: 扫描完成后回到首页
- **WHEN** 扫描在后台完成，用户从其他 Tab 回到首页
- **THEN** 首页展示完成后的数据，不出现旧计数或空白

### Requirement: Tab 页面状态保活
系统 SHALL 保留已访问 Tab 的滚动位置、筛选条件与编辑状态，且未访问的 Tab 不构建、不参与布局。

#### Scenario: 切换 Tab 后返回
- **WHEN** 用户在「筛选」页滚动到中部，切到「文案」再切回
- **THEN** 筛选页保持原来的滚动位置与选中分类

#### Scenario: 未访问 Tab 不初始化
- **WHEN** 应用首次启动停留在首页
- **THEN** 月刊、文案、索引页不执行初始化逻辑（如加载照片、创建 WebView）

### Requirement: 缩略图管线
系统 SHALL 为每张入库照片生成最长边 256px 的 JPEG 缩略图并持久化到应用缓存目录，`Photo.thumbnailPath` 指向该缩略图；删除照片时同时删除缩略图文件。

#### Scenario: 新扫描照片生成缩略图
- **WHEN** 扫描到一张 4000×3000 的原图
- **THEN** 缓存目录生成最长边 256px 的缩略图，列表使用缩略图渲染

#### Scenario: 旧数据补缩略图
- **WHEN** 已存在记录的 `thumbnailPath` 仍等于原图路径
- **THEN** 下一次扫描时为该记录补生成缩略图并更新记录

#### Scenario: 删除照片
- **WHEN** 用户删除一张照片
- **THEN** 原图、缩略图与数据库记录同时移除

### Requirement: 解码尺寸 DPR 感知
系统 SHALL 按「逻辑显示尺寸 × devicePixelRatio」计算 `cacheWidth/cacheHeight`，并将其限制在合理上限，避免高 DPI 模糊与低 DPI 过解码。

#### Scenario: 3x 屏幕缩略图
- **WHEN** 在 3x 屏幕渲染 72dp 缩略图
- **THEN** 解码尺寸为 216px 级别而非 108px，肉眼不模糊

#### Scenario: 无尺寸约束的图片
- **WHEN** 调用方未传宽高
- **THEN** 使用父约束 × DPR 推导解码尺寸，仍无法推导时按原图解码

### Requirement: 增量与并发扫描
系统 SHALL 跳过已入库且已有缩略图的照片，并以不超过 4 的并发度处理相册元数据与缩略图生成。

#### Scenario: 第二次扫描
- **WHEN** 已有 2000 张照片入库且缩略图完整，设备仅新增 10 张
- **THEN** 扫描只处理新增照片，不重复读取已有照片的文件信息

#### Scenario: 强制重扫
- **WHEN** 用户触发强制重扫
- **THEN** 刷新已有照片的元数据，但不产生重复记录

### Requirement: 数据查询热路径
系统 SHALL 以单次遍历/索引方式完成月份分组、相簿照片查询与相簿计数，避免随照片数增长的嵌套扫描。

#### Scenario: 万张照片月份分组
- **WHEN** 未整理照片数量达到 10000 张
- **THEN** 月份分组只遍历一次，不出现 O(n²) 的 `where().firstOrNull`

#### Scenario: 相簿列表
- **WHEN** 打开「相簿」Tab，存在 50 个相簿
- **THEN** 每个相簿的照片数来自一次批量统计，不在 build 中逐个读取 Box

### Requirement: 模块化月刊页
系统 SHALL 将月刊页拆分为模型、模板渲染、底部面板、A4 排版、时间线五个模块，单文件不超过 900 行，行为与拆分前一致。

#### Scenario: 月刊功能回归
- **WHEN** 用户切换 6 种模板、4 种胶片品牌、导入照片、编辑文案、导出 A4 与单图
- **THEN** 输出效果与拆分前一致，无功能缺失

### Requirement: 可访问性与扫描反馈
系统 SHALL 为主要可点击区域提供语义标签与不小于 48dp 的触控区域，并在扫描过程中给出明确的加载反馈。

#### Scenario: 扫描中的筛选页
- **WHEN** 照片表为空且正在扫描
- **THEN** 显示骨架屏与「正在扫描」提示，而不是「所有照片已整理完成」

#### Scenario: 屏幕阅读器
- **WHEN** 使用 TalkBack 浏览底部 Tab
- **THEN** 每个 Tab 朗读其名称与选中状态

### Requirement: 自动化验证
系统 SHALL 通过 `flutter analyze`（0 error）、`flutter test`（全部通过）与 debug APK 构建；模拟器可用时 SHALL 通过 adb 完成启动、权限、五个 Tab 切换与关键流程验证。

#### Scenario: 静态与单元测试
- **WHEN** 执行 `flutter analyze` 与 `flutter test`
- **THEN** 无 error，测试全部通过

#### Scenario: 模拟器验证
- **WHEN** 连接模拟器/真机并安装 debug APK
- **THEN** 应用可授予权限、完成扫描、切换全部 Tab，logcat 无 FATAL

## MODIFIED Requirements

### Requirement: 图片加载组件
`LocalImage` 的缓存尺寸推导从「固定 ×1.5」改为「× devicePixelRatio，带上限」，并保留显式 `cacheWidth/cacheHeight` 优先级与 LayoutBuilder 兜底逻辑。

### Requirement: 主界面导航
底部 Tab 容器从「Widget 实例缓存 + 单页渲染」改为「首次访问创建 + Offstage 保活」，Tab 切换不再重建已访问页面。
