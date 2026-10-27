# 整个 App UI 交互优化方案（awesome-ui 风格）

## 设计原则

参考 Apple HIG + Material 3 Expressive，4 条核心原则：

1. **统一语言**：所有按钮/弹窗/顶栏/卡片走同一套 token 和组件库，消灭 20+ 套散落按钮、4 种弹窗、5 种顶栏
2. **层次清晰**：通过阴影、模糊、缩放建立 z 轴深度，关键操作突出，次要操作收敛
3. **微动效**：列表入场 stagger、按钮按压缩放、chip 切换过渡、BottomSheet 滑入，时长统一走 `AppTransitions` token
4. **触感反馈**：导入/删除/导出/切换加 `HapticFeedback`，提升物理感

## 现状问题（基于整 app 审计）

### 散落组件统计
- **20+ 套手写按钮**（`_iconBtn`×2、`_navBtn`、`_actionBtn`×2、`_menuItem`、`_statItem`、`_themeOption`、preset chip、fetch button、category chip、fission button、AI badge、timeline op button、album chip、delete button×3、select ring、EmptyState CTA）
- **4 种弹窗实现**（AlertDialog / Dialog+GlassCard / BottomBlurBar / 自建 _DeleteConfirmationSheet）
- **5 套顶栏模式**（NavHeader / `_buildTopBar`×2 / `_buildHeader`×4 / SliverAppBar 自定义）
- **6 档图标盒尺寸**（28/32/36/40/44/48/64/72）
- **3 套骨架屏**（仅 monthly_magazine 有，且是内联实现）

### 硬编码值统计
- 7 种黑色叠层（black54/87、black.withOpacity(0.4/0.6/0.7/0.15/0.08)、Color(0x29000000)、scrim、overlay）
- 5 种白色透明度
- 6 档圆角（2/4/12/16/20/24/999 散落）
- 6 档时长（50/100/150/200/220/1500ms 硬编码，未走 AppTransitions）
- 4 档 accent 透明度（0.06/0.08/0.1/0.3）

### 动画缺失
- 11 个页面中 8 个无任何动画
- 仅 3 个页面有 AnimatedContainer，1 个页面有 stagger 入场
- AppTransitions.spring/springBouncy/ease 0 次使用

### 空状态/loading 缺失
- home_page 缺空状态和 loading
- smart_filter_page 缺 loading
- slide_box_page 删除时无 loading 反馈

## 组件层升级

### 新增组件（4 个）

#### 1. `AppButton`（统一按钮）`lib/components/app_button.dart` — **已创建，待启用**
- 5 种 variant：primary/secondary/ghost/danger/outline
- 3 档 size：sm(28)/md(36)/lg(44)
- 3 种 shape：pill/rect/circle
- 内置按压缩放（100ms easeOut）+ HapticFeedback
- 替换 20 套散落按钮中的 15+ 套

#### 2. `AppDialog`（统一对话框）`lib/components/app_dialog.dart`
```dart
// 用法
AppDialog.show(context, title: '编辑文案', icon: Icons.text_fields, children: [...]);
AppDialog.confirm(context, title: '删除照片', message: '...', danger: true, onConfirm: ...);
AppDialog.input(context, title: '新建相簿', hint: '输入名称', onConfirm: (text) ...);
```
- 风格：居中卡片 + `AppRadii.xxl` 圆角 + 阴影 + 顶部渐变 icon 盒
- 替换 7 处 AlertDialog + 1 处自建 `_DeleteConfirmationSheet` + 1 处 GlassCard Dialog

#### 3. `ShimmerSkeleton`（骨架屏）`lib/components/shimmer_skeleton.dart`
```dart
ShimmerSkeleton.box(width, height, radius);
ShimmerSkeleton.list({itemCount, itemHeight});
ShimmerSkeleton.timeline({itemCount}); // 月刊专用
```
- 基于 LinearGradient + AnimationController，800ms 循环流光
- 颜色 `bgSubtle → bgMuted → bgSubtle`
- 替换 monthly_magazine `_buildSkeleton` 内联实现
- 给 home_page / smart_filter_page / slide_box_page 补 loading

#### 4. `AppChip`（统一 chip）`lib/components/app_chip.dart`
```dart
enum AppChipStyle { selectable, tag, action }
AppChip.selectable(label, selected: true, onTap: ...);
AppChip.tag(label);
AppChip.action(icon, label, onTap: ...);
```
- 替换 `_buildOptionChip`、关键词 chip、category chip、preset chip、AI badge、album chip

### 升级组件（4 个）

#### 1. `NavHeader` 升级
- 新增 `transparent: bool`（沉浸式顶栏）
- 新增 `subtitle: String?`（月刊页用）
- 新增 `leading: Widget?`（自定义返回，photo_detail SliverAppBar 用）
- 替换 5 套自建顶栏

#### 2. `BottomBlurBar` 升级
- 新增 `dismissible: bool`（下滑关闭）
- 标题栏 icon 盒加 100ms 按压缩放
- 圆角 24 → `AppRadii.xxl` token

#### 3. `EmptyState` 升级
- CTA 按钮改用 `AppButton.primary`（去重）
- 新增 `tone: EmptyStateTone.skeleton` 用于骨架屏占位提示

#### 4. `LoadingOverlay` 升级
- 新增 `variant: LoadingVariant.overlay / inline / card` 三种
- `inline` 用于按钮内小菊花（替换散落 `CircularProgressIndicator(strokeWidth: 2)`）

## Token 层升级（lib/theme.dart）

### 新增 token
```dart
// 图标盒尺寸
abstract class AppIconSizes {
  static const double xs = 24;  // chip icon
  static const double sm = 32;  // nav 返回
  static const double md = 36;  // _iconBtn
  static const double lg = 44;  // sheet header icon
  static const double xl = 48;  // month header
  static const double xxl = 64; // delete icon
}

// accent 透明度档位
abstract class AppOpacities {
  static const double accentBg = 0.08;   // accent 背景填充
  static const double accentBorder = 0.3; // accent 边框
  static const double accentShadow = 0.3; // accent 阴影
  static const double blackOverlay = 0.4; // 黑色叠层
  static const double whiteOverlay = 0.7; // 白色叠层
}

// 阴影工厂
abstract class AppShadows {
  // 现有 sm/md/lg 保持
  static BoxShadow accentShadow(BuildContext context, {double opacity = 0.3}) => ...;
  static BoxShadow dangerShadow(BuildContext context, {double opacity = 0.3}) => ...;
  static BoxShadow sheetShadow(BuildContext context) => ...; // 替换 Color(0x29000000)
}

// 时长统一
abstract class AppTransitions {
  static const Duration instant = Duration(milliseconds: 80);  // 按压
  static const Duration fast = Duration(milliseconds: 150);    // chip/tab
  static const Duration normal = Duration(milliseconds: 250);  // 入场/sheet
  static const Duration slow = Duration(milliseconds: 400);    // 页面
  static const Duration shimmer = Duration(milliseconds: 800); // 骨架流光
}
```

### 修复 bug
- `AppShadows.smDark / mdDark / lgDark` 改为 `const`（theme.dart:240-254）

## 各页面改造点

### P0 - 组件启用与弹窗统一（影响 9 个文件）

| 文件 | 改造内容 |
|------|---------|
| `monthly_magazine_page.dart` | 顶栏改 NavHeader；6 处 BottomBlurBar 内部 chip/按钮换 AppButton/AppChip；`_editCaption` 换 AppDialog；`_confirmDeletePhoto` 换 AppDialog.confirm；`_showSingleExportPicker` 改用 BottomBlurBar |
| `smart_filter_page.dart` | 3 处 AlertDialog 换 AppDialog（新建/重命名相簿/关于整理）；3 处 BottomBlurBar 内部换 AppButton；`_iconBtn` 换 AppButton.circle；`_menuItem` 换 AppButton.rect |
| `slide_box_page.dart` | 退出确认 AlertDialog 换 AppDialog.confirm；`_actionBtn`×3 换 AppButton；close 按钮换 AppButton.circle；index/delete pill 换 AppChip |
| `photo_detail_page.dart` | `_DeleteConfirmationSheet` 整个删除，改用 `showModalBottomSheet + BottomBlurBar`；close 按钮换 AppButton.circle；删除按钮换 AppButton.danger |
| `cleanup_suggestion_page.dart` | `_deleteSelected` AlertDialog 换 AppDialog.confirm；清理按钮换 AppButton.danger；自建遮罩换 LoadingOverlay；选择圆环抽组件 |
| `curated_photos_page.dart` | 收藏 toggle 按钮换 AppButton.circle |
| `home_page.dart` | `_iconBtn` 换 AppButton.circle |
| `ai_config_dialog.dart` | 整体改用 AppDialog.show 包装；preset chip 换 AppChip；测试/保存按钮换 AppButton |
| `quote_library_page.dart` | fetch/fission button 换 AppButton；category chip 换 AppChip；AI badge 换 AppChip |

### P1 - 顶栏统一（5 个文件）

| 文件 | 改造 |
|------|------|
| `home_page.dart` | `_buildHeader` → 用 NavHeader.transparent + 自定义 action（设置按钮） |
| `monthly_magazine_page.dart` | `_buildTopBar` → NavHeader.transparent + action(导入按钮)；`_buildMonthNav` → NavHeader.subtitle |
| `slide_box_page.dart` | `_buildTopBar` → NavHeader.transparent + leading(close) + action(index pill) |
| `smart_filter_page.dart` | `_buildHeader` → NavHeader.transparent + action(更多按钮) |
| `quote_library_page.dart` | inline header → NavHeader.transparent + action(fetch button) |
| `photo_detail_page.dart` | SliverAppBar leading → AppButton.circle |

### P1 - 骨架屏与空状态补全（3 个文件）

| 文件 | 改造 |
|------|------|
| `home_page.dart` | 首次扫描时显示 `ShimmerSkeleton`（hero + stats + recent + timeline 占位） |
| `smart_filter_page.dart` | 数据加载时显示 `ShimmerSkeleton.list` |
| `slide_box_page.dart` | `_performDelete` 时显示 `LoadingOverlay` |

### P2 - 硬编码 token 替换（全文件）

| 类别 | 替换规则 | 影响位置 |
|------|---------|---------|
| 黑色叠层 | `Colors.black54/87` → `context.scrim`；`Colors.black.withOpacity(0.4/0.6/0.7)` → `context.overlay` | 15+ 处 |
| 白色透明 | `Colors.white70` → `Colors.white.withOpacity(0.7)`；`Colors.white24` → `Colors.white.withOpacity(0.24)` | 8 处 |
| 圆角 999 | `BorderRadius.circular(999)` → `BorderRadius.circular(AppRadii.full)` | 12 处 |
| 圆角 16 | `BorderRadius.circular(16)` → `AppRadii.xl` | 4 处 |
| 圆角 12 | `BorderRadius.circular(12)` → `AppRadii.lg` | 3 处 |
| 圆角 24 | `Radius.circular(24)` → `AppRadii.xxl` | 2 处 |
| 时长 | `Duration(milliseconds: 50/100/150/200/220)` → `AppTransitions.instant/fast/normal` | 10+ 处 |
| accent 透明度 | 0.06/0.08/0.1 → `AppOpacities.accentBg`；0.3 → `AppOpacities.accentShadow` | 8 处 |
| 硬编码颜色 | `Color(0xFF164f3c)` → `AppColors.success`；`Color(0xFFE91E63)` → `AppColors.error`；A4 文字色 `Color(0xFF333333/999999/CCCCCC/EEEEEE)` → `AppColors.textPrimary/Secondary/Tertiary/divider` | 6 处 |

### P2 - 入场动画（5 个文件）

| 文件 | 动画 |
|------|------|
| `home_page.dart` | stat card / memory card / timeline group stagger 淡入上滑（300ms easeOutCubic，index×40ms 延迟） |
| `curated_photos_page.dart` | grid item stagger 淡入 |
| `quote_library_page.dart` | quote card stagger 淡入 |
| `monthly_magazine_page.dart` | 时光线条目 stagger 淡入上滑 |
| `settings_page.dart` | section stagger 淡入 |

封装为可复用 widget：
```dart
// lib/components/staggered_fade_in.dart
class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration; // 默认 AppTransitions.normal
  // ...
}
```

### P3 - 触感反馈（全文件）

| 操作 | 反馈 | 位置 |
|------|------|------|
| 导入照片 | lightImpact | `_showImporter` |
| 导入完成 | mediumImpact | `_showImporter` 末尾 |
| 删除照片 | heavyImpact | `_confirmDeletePhoto` |
| 导出 | lightImpact | `_captureA4` / `_exportSinglePhoto` |
| 模板切换 | selectionClick | `_changeTemplate` |
| 收藏切换 | selectionClick | `curated_photos_page` toggle |
| 相簿长按 | mediumImpact | `smart_filter_page` 长按 |
| 卡片拖拽阈值触发 | heavyImpact | `slide_box_page` |

### P3 - 死代码清理

- `app_state.dart`：删除 `showSlideBox/slideBoxPhotos/slideBoxTitle/showSlideBoxPage/closeSlideBoxPage` 整组 API（10-12、20-22、72-84 行）

## 不做的事（避免过度工程）

- ❌ 不引入 rive/lottie 动画库
- ❌ 不做粒子/3D 效果
- ❌ 不改 6 个 MagTemplate 内部渲染（已稳定）
- ❌ 不改 webview 胶片索引页内部（仅 FAB 颜色）
- ❌ 不改数据层/状态管理（仅 UI 层）
- ❌ 不改路由结构（保持 IndexedStack + PageTransition）

## 实施分阶段

### 阶段 1：Token + 组件层
- 修复 `AppShadows.smDark/mdDark/lgDark` const 问题
- 新增 `AppIconSizes` / `AppOpacities` token
- 新增 `AppShadows.accentShadow/dangerShadow/sheetShadow`
- 补全 `AppTransitions.instant/shimmer`
- 新建 `AppButton`（已存在，启用）/ `AppDialog` / `ShimmerSkeleton` / `AppChip` / `StaggeredFadeIn`
- 升级 `NavHeader`（transparent/subtitle/leading）/ `BottomBlurBar`（dismissible）/ `EmptyState`（用 AppButton）/ `LoadingOverlay`（variant）

### 阶段 2：弹窗统一 + 按钮统一（P0）
- 9 个文件的 AlertDialog / 自建 sheet / 散落按钮全部替换

### 阶段 3：顶栏统一 + 骨架屏补全（P1）
- 5 个文件顶栏改 NavHeader
- 3 个文件补 ShimmerSkeleton / LoadingOverlay

### 阶段 4：硬编码替换 + 入场动画（P2）
- 全文件 token 替换
- 5 个文件加 StaggeredFadeIn

### 阶段 5：触感反馈 + 死代码清理（P3）
- 8 处关键操作加 HapticFeedback
- 删除 AppState 死代码

## 涉及文件

| 文件 | 操作 | 阶段 |
|------|------|------|
| `lib/theme.dart` | 修改（token 新增 + const 修复） | 1 |
| `lib/components/app_button.dart` | 已存在，启用 | 1-2 |
| `lib/components/app_dialog.dart` | 新建 | 1 |
| `lib/components/shimmer_skeleton.dart` | 新建 | 1 |
| `lib/components/app_chip.dart` | 新建 | 1 |
| `lib/components/staggered_fade_in.dart` | 新建 | 1 |
| `lib/components/nav_header.dart` | 修改 | 1 |
| `lib/components/bottom_blur_bar.dart` | 修改 | 1 |
| `lib/components/empty_state.dart` | 修改 | 1 |
| `lib/components/loading_overlay.dart` | 修改 | 1 |
| `lib/pages/monthly_magazine_page.dart` | 修改（最大改动） | 2-4 |
| `lib/pages/smart_filter_page.dart` | 修改 | 2-4 |
| `lib/pages/slide_box_page.dart` | 修改 | 2-4 |
| `lib/pages/photo_detail_page.dart` | 修改 | 2-4 |
| `lib/pages/cleanup_suggestion_page.dart` | 修改 | 2-4 |
| `lib/pages/curated_photos_page.dart` | 修改 | 2-4 |
| `lib/pages/home_page.dart` | 修改 | 3-4 |
| `lib/pages/quote_library_page.dart` | 修改 | 2-4 |
| `lib/pages/settings_page.dart` | 修改 | 3-4 |
| `lib/pages/ai_config_dialog.dart` | 修改 | 2 |
| `lib/pages/film_index_page.dart` | 修改（仅 FAB 颜色） | 4 |
| `lib/app_state.dart` | 修改（删死代码） | 5 |
| `lib/main.dart` | 修改（PageTransition 时长） | 4 |

## 验证

1. `flutter analyze` → 0 error / 0 warning
2. 视觉验证（每个页面）：
   - 顶栏风格统一（NavHeader 或其 transparent 变体）
   - 按钮风格统一（AppButton 5 种 variant）
   - 弹窗风格统一（AppDialog 居中 / BottomBlurBar 底部）
   - 列表入场有 stagger 动画
   - 骨架屏有 shimmer 流光
3. 交互验证：
   - 按钮按压有缩放反馈
   - 关键操作有触感反馈
   - BottomSheet 可下滑关闭
   - chip 切换有 150ms 过渡
4. 一致性验证：
   - 无硬编码圆角（grep `circular(999)` / `circular(16)` / `circular(24)` 应为 0）
   - 无硬编码黑色叠层（grep `Colors.black54` / `Colors.black87` 应为 0）
   - 无硬编码时长（grep `Duration(milliseconds:` 应仅剩 AppTransitions 定义）

## 预期收益

- 代码量减少：删除 20 套散落按钮 + 4 套弹窗 + 5 套顶栏，预计净减 800-1200 行
- UI 一致性：从 4 种弹窗/5 种顶栏/20 种按钮 → 2 种弹窗/1 种顶栏/5 种按钮
- 性能：StaggeredFadeIn 用 RepaintBoundary 隔离，不影响滚动性能
- 可维护性：新增页面只需组合 AppButton/AppDialog/AppChip，无需重写
