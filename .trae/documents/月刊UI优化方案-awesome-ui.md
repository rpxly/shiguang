# 月刊页 UI 优化方案（awesome-ui 风格）

## 设计原则

参考 Apple HIG + Material 3 Expressive，遵循 4 条核心原则：

1. **统一语言**：所有弹窗、按钮、卡片走同一套 token 和组件库，消灭硬编码（圆角 24、999）
2. **层次清晰**：通过阴影、模糊、缩放建立 z 轴深度，关键操作突出，次要操作收敛
3. **微动效**：入场/切换/反馈用 150-300ms 动画过渡，告别"瞬切"
4. **触感反馈**：关键操作（导入/删除/导出）加 `HapticFeedback.lightImpact()`，提升物理感

## 现状问题清单

| # | 问题 | 位置 |
|---|------|------|
| 1 | 4 种弹窗风格并存（BottomBlurBar / 自建 / GlassCard / AlertDialog） | `_showSingleExportPicker` / `_editCaption` / `_confirmDeletePhoto` |
| 2 | 5 种按钮散落私有方法，未抽组件 | `_timelineOpBtn` / `_iconBtn` / `_navBtn` / `_buildOptionChip` / `_shareOption` |
| 3 | 骨架屏纯静态灰块，无 shimmer | `_buildSkeleton` |
| 4 | 时光线无入场动画 | `_buildTimelineView` |
| 5 | 硬编码圆角（24 / 999） | `_showSingleExportPicker` / 关键词 chip / 把手 |
| 6 | TopBar 自建，不用 NavHeader | `_buildTopBar` |
| 7 | chip 选中动画 150ms 是唯一动画 | `_buildOptionChip` |
| 8 | 无触感反馈 | 所有 onTap |

## 组件层升级（新增 4 个组件 + 升级 2 个）

### 新增 1：`AppButton`（统一按钮）`lib/components/app_button.dart`

替换 `_timelineOpBtn` / `_iconBtn` / `_navBtn` / 步数弹窗双按钮 / 删除按钮等。

```dart
enum AppButtonVariant {
  primary,    // 渐变填充 + 白字 + 阴影（主操作：保存、导入）
  secondary,  // bgSubtle 填充 + textPrimary（次操作：取消）
  ghost,      // 透明 + textSecondary（幽灵：文案/模板/导出小按钮）
  danger,     // error 填充 + 白字（删除确认）
  outline,    // divider 边框 + textPrimary（圆形导航）
}

enum AppButtonSize { sm, md, lg }  // 28/36/44 高度
enum AppButtonShape { pill, rect, circle }  // full / md / circle
```

### 新增 2：`AppDialog`（统一对话框）`lib/components/app_dialog.dart`

替换 `_editCaption`（GlassCard）和 `_confirmDeletePhoto`（AlertDialog）。

```dart
// 用法
AppDialog.show(context, title: '编辑文案', icon: Icons.text_fields, children: [...]);
AppDialog.confirm(context, title: '删除照片', message: '...', danger: true);
```

- 风格：居中卡片 + `AppRadii.xxl` 圆角 + 阴影 + 顶部渐变 icon 盒
- 与 BottomBlurBar 形成互补：底部操作用 BottomBlurBar，居中确认/编辑用 AppDialog

### 新增 3：`ShimmerSkeleton`（骨架屏）`lib/components/shimmer_skeleton.dart`

替换 `_buildSkeleton` 内联实现。

- 基于 `LinearGradient` + `AnimationController` 实现 shimmer 流光效果
- 提供 `ShimmerSkeleton.box(width, height)` 和 `ShimmerSkeleton.list(...)` 工厂
- 800ms 周期，循环播放

### 新增 4：`AppChip`（统一 chip）`lib/components/app_chip.dart`

替换 `_buildOptionChip` 和关键词 chip。

```dart
enum AppChipStyle {
  selectable,  // 选中/未选中（心情/天气）
  tag,         // 标签（关键词）
  action,      // 可点击带 icon
}
```

### 升级 1：`BottomBlurBar`

- 新增 `dismissible: bool` 参数，支持下滑手势关闭（`DraggableScrollableSheet` 集成）
- 标题栏 icon 盒加微缩放动画（点击时 scale 0.96 → 1.0）

### 升级 2：`NavHeader`

- 新增 `transparent: bool` 参数，支持透明背景（用于月刊页沉浸式顶栏）
- 新增 `subtitle: String?` 参数

## 月刊页具体改造点

### 改造 1：TopBar 改用 NavHeader（+ 沉浸式）

**位置**：[_buildTopBar L2410-2424](file:///f:/daima/ai-album/lib/pages/monthly_magazine_page.dart#L2410-L2424)

- 替换为 `NavHeader(transparent: true, title: '月刊', onBack: widget.onBack, action: 导入按钮)`
- 月份导航 [_buildMonthNav](file:///f:/daima/ai-album/lib/pages/monthly_magazine_page.dart#L2442-L2457) 整合进 NavHeader 副标题位
- 月份切换按钮用 `AppButton(variant: outline, shape: circle, size: sm)`

### 改造 2：弹窗全部统一

| 弹窗 | 当前 | 改造后 |
|------|------|--------|
| `_showMoodPicker` | BottomBlurBar | 保持，chip 换 AppChip |
| `_showWeatherPicker` | BottomBlurBar | 保持，chip 换 AppChip |
| `_showStepsPicker` | BottomBlurBar | 保持，按钮换 AppButton |
| `_showShareOptions` | BottomBlurBar | 保持，`_shareOption` 换 AppButton.listTile |
| `_showSingleExportPicker` | 自建容器 | 改用 BottomBlurBar + 自定义 headerExtra |
| `_editCaption` | GlassCard 对话框 | 改用 AppDialog |
| `_confirmDeletePhoto` | AlertDialog | 改用 AppDialog.confirm(danger: true) |

### 改造 3：时光线动画

**位置**：[_buildTimelineView L1675-1732](file:///f:/daima/ai-album/lib/pages/monthly_magazine_page.dart#L1675-L1732)

- 每个 `_buildTimelineEntry` 包 `TweenAnimationBuilder<double>`（0.0 → 1.0，300ms，Curves.easeOutCubic）
- 动画值驱动：`Opacity` + `Transform.translate(0, 20 * (1-t))`（上滑淡入）
- 通过 index 计算 stagger 延迟：`begin: Duration(milliseconds: index * 40)`（前 6 个有延迟，后续立即）

### 改造 4：时光线操作按钮升级

**位置**：[_timelineOpBtn L1851-1864](file:///f:/daima/ai-album/lib/pages/monthly_magazine_page.dart#L1851-L1864)

- 换为 `AppButton(variant: ghost, size: sm, icon: ..., label: ...)`
- 加 `InkWell` 水波纹（替换裸 GestureDetector）
- 加 `HapticFeedback.selectionClick()` 触感

### 改造 5：月份概览卡片升级

**位置**：[_buildMonthHeader L1566-1657](file:///f:/daima/ai-album/lib/pages/monthly_magazine_page.dart#L1566-L1657)

- 月份方块加 `AnimatedScale`（点击时 0.95 → 1.0）
- 统计项 `_buildStatItem` 加 `InkWell` 圆角水波纹
- 关键词 chip 换 `AppChip(style: tag)`

### 改造 6：骨架屏 shimmer

**位置**：[_buildSkeleton L2470-2511](file:///f:/daima/ai-album/lib/pages/monthly_magazine_page.dart#L2470-L2511)

- 替换为 `ShimmerSkeleton.list(itemCount: 3, itemHeight: 180)`
- 流光从左到右循环，颜色用 `bgSubtle → bgMuted → bgSubtle`

### 改造 7：硬编码 token 修正

| 位置 | 硬编码 | 改为 |
|------|--------|------|
| `_showSingleExportPicker` 圆角 24 | `Radius.circular(24)` | `Radius.circular(AppRadii.xxl)` |
| BottomBlurBar 把手 999 | `BorderRadius.circular(999)` | `BorderRadius.circular(AppRadii.full)` |
| 关键词 chip 999 | `BorderRadius.circular(999)` | `AppChip(style: tag)` |

### 改造 8：导入/导出/删除触感反馈

| 操作 | 位置 | 反馈 |
|------|------|------|
| 导入按钮点击 | `_showImporter` | `HapticFeedback.lightImpact()` |
| 导入完成 | `_showImporter` 末尾 | `HapticFeedback.mediumImpact()` |
| 删除按钮点击 | `_confirmDeletePhoto` | `HapticFeedback.heavyImpact()` |
| 导出按钮点击 | `_captureA4` / `_exportSinglePhoto` | `HapticFeedback.lightImpact()` |
| 模板切换 | `_changeTemplate` | `HapticFeedback.selectionClick()` |

## 动效系统总览

| 动效类型 | 时长 | 曲线 | 用途 |
|---------|------|------|------|
| 微交互 | 100ms | easeOut | 按钮按压缩放 |
| 切换 | 150ms | easeOut | chip 选中、tab 切换 |
| 入场 | 300ms | easeOutCubic | 时光线 stagger、卡片淡入 |
| 页面 | 400ms | easeOutCubic | BottomSheet 滑入 |
| Shimmer | 800ms | linear (loop) | 骨架屏流光 |

## 不做的事（避免过度工程）

- ❌ 不引入 rive / lottie 动画库（保持依赖轻量）
- ❌ 不做粒子/3D 效果（与极简杂志风冲突）
- ❌ 不改 6 个 MagTemplate 内部渲染（已在上一轮修复稳定）
- ❌ 不改数据层/状态管理（仅 UI 层）
- ❌ 不改其他页面（仅月刊页 + 新增通用组件）

## 实施分阶段

### 阶段 1：组件层（新增 4 组件 + 升级 2 组件）
- 新建 `app_button.dart` / `app_dialog.dart` / `shimmer_skeleton.dart` / `app_chip.dart`
- 升级 `bottom_blur_bar.dart`（dismissible + icon 缩放）
- 升级 `nav_header.dart`（transparent + subtitle）

### 阶段 2：弹窗统一（7 个弹窗改造）
- `_showSingleExportPicker` 改用 BottomBlurBar
- `_editCaption` 改用 AppDialog
- `_confirmDeletePhoto` 改用 AppDialog.confirm
- 其余 4 个弹窗内部 chip/按钮换新组件

### 阶段 3：月刊页主体改造
- TopBar 改用 NavHeader
- 月份导航用 AppButton.circle
- 月份概览卡片动画 + AppChip
- 时光线 stagger 入场动画
- 操作按钮换 AppButton.ghost
- 骨架屏换 ShimmerSkeleton

### 阶段 4：触感反馈 + 细节打磨
- 5 处关键操作加 HapticFeedback
- 硬编码 token 全部替换为 AppRadii
- flutter analyze 验证 0 error / 0 warning

## 涉及文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/components/app_button.dart` | 新建 | 统一按钮组件 |
| `lib/components/app_dialog.dart` | 新建 | 统一对话框组件 |
| `lib/components/shimmer_skeleton.dart` | 新建 | shimmer 骨架屏 |
| `lib/components/app_chip.dart` | 新建 | 统一 chip |
| `lib/components/bottom_blur_bar.dart` | 修改 | 加 dismissible + icon 动画 |
| `lib/components/nav_header.dart` | 修改 | 加 transparent + subtitle |
| `lib/pages/monthly_magazine_page.dart` | 修改 | 主体改造（弹窗/顶栏/时光线/概览/骨架） |

## 验证

1. `flutter analyze` → 0 error / 0 warning
2. 视觉验证：
   - 进入月刊页：骨架屏 shimmer 流光
   - 数据加载完成：时光线条目 stagger 上滑淡入
   - 点击导入/删除/导出：有触感反馈
   - 所有弹窗视觉风格统一（圆角、阴影、标题栏）
   - 删除确认弹窗用 danger 风格（红色按钮）
   - 编辑文案弹窗用居中 AppDialog（不再是底部 GlassCard）
3. 交互验证：
   - BottomSheet 可下滑关闭
   - 按钮按压有缩放反馈
   - chip 切换有 150ms 过渡
