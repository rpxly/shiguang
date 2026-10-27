# AI 相册 — 完整设计规格

> 版本: 1.0 | 更新日期: 2026-07-01
> 本文档为开发团队交付的唯一设计参考，涵盖所有设计决策、组件规格、导航架构与 AI 管线定义。

---

## 1. 项目概览

### 1.1 基本信息

| 项目 | 说明 |
|------|------|
| **App 名称** | AI 相册 |
| **产品定位** | 个人记忆管家 — 基于 AI 视觉分析的照片管理与回忆叙事工具 |
| **目标用户** | 注重生活记录的智能手机用户，希望 AI 自动整理照片并生成时间线叙事 |
| **设备类型** | 移动端（max-width: 420px） |
| **语言** | zh-CN（中文） |

### 1.2 设计风格

**风格关键词**: Magazine Minimal + Glassmorphism

- **极简杂志风**: 冷灰中性色调、大留白、编辑式排版，AI 生成的文案作为记忆叙事主线
- **玻璃拟态 (Glassmorphism)**: 毛玻璃面板效果，营造层次感与现代感
- **明暗双模式**: 完整的 light / dark 主题支持
- **视觉密度**: 低密度；彩色只允许出现在背景的低饱和环境光渐变里，卡片与控件一律中性
- **交互基调**: 安静、杂志翻页般的体验感

### 1.3 设计约束

| 约束 | 值 |
|------|------|
| 最大圆角 | 24px（卡片 18 / 面板 24） |
| 静态阴影最大透明度 | 0.08 |
| 布局方差 | 3（中等变化） |
| 动效强度 | 2（克制动效） |
| 视觉密度 | 2（低密度） |

> **v1.1 修订（玻璃材质重构）**：原「避免彩色渐变」与「阴影 ≤0.05」两条已废弃。
> 原因：玻璃拟态必须有可模糊的内容，纯色 `#FAFAFA` 底会让半透明面板退化成白卡叠白底，
> 白天模式下完全失效。现改为「低饱和环境光渐变 + 阴影 ≤0.08」。

---

## 2. 设计系统 (Design Tokens)

### 2.1 色彩系统

#### 亮色模式 (:root)

| Token | 值 | 用途 |
|-------|------|------|
| `--color-bg` | `#FAFAFA` | 页面背景 |
| `--color-bg-elevated` | `#FFFFFF` | 悬浮/卡片背景 |
| `--color-bg-subtle` | `#F3F4F6` | 次要背景、占位符 |
| `--color-bg-muted` | `#E5E7EB` | 弱化背景 |
| `--color-text-primary` | `#111827` | 主文字 |
| `--color-text-secondary` | `#6B7280` | 次要文字 |
| `--color-text-tertiary` | `#9CA3AF` | 弱化文字/标签 |
| `--color-text-inverse` | `#FFFFFF` | 反色文字（深色背景上） |
| `--color-primary` | `#374151` | 主色（近黑中性灰） |
| `--color-primary-hover` | `#1F2937` | 主色悬停态 |
| `--color-primary-light` | `rgba(55, 65, 81, 0.08)` | 主色浅底 |
| `--color-border` | `rgba(0, 0, 0, 0.06)` | 卡片边框 |
| `--color-border-subtle` | `rgba(0, 0, 0, 0.04)` | 弱化边框 |
| `--color-divider` | `rgba(0, 0, 0, 0.05)` | 分割线 |
| `--color-overlay` | `rgba(0, 0, 0, 0.4)` | 遮罩层 |
| `--color-scrim` | `rgba(0, 0, 0, 0.6)` | 深遮罩层 |

#### 状态颜色

| Token | 值 | 用途 |
|-------|------|------|
| `--state-success` | `#059669` | 完成/成功 |
| `--state-warning` | `#D97706` | 警告 |
| `--state-error` | `#DC2626` | 错误/删除 |
| `--state-info` | `#2563EB` | 信息/进行中 |

#### 暗色模式 (.dark)

| Token | 值 | 用途 |
|-------|------|------|
| `--color-bg` | `#0C0C0E` | 页面背景（极深黑） |
| `--color-bg-elevated` | `#161618` | 悬浮背景 |
| `--color-bg-subtle` | `#1C1C1F` | 次要背景 |
| `--color-bg-muted` | `#2A2A2E` | 弱化背景 |
| `--color-text-primary` | `#F5F5F7` | 主文字 |
| `--color-text-secondary` | `#A1A1AA` | 次要文字 |
| `--color-text-tertiary` | `#71717A` | 弱化文字 |
| `--color-text-inverse` | `#0C0C0E` | 反色文字 |
| `--color-primary` | `#E5E5EA` | 主色（近白中性灰） |
| `--color-primary-hover` | `#F5F5F7` | 主色悬停态 |
| `--color-primary-light` | `rgba(229, 229, 234, 0.1)` | 主色浅底 |
| `--color-border` | `rgba(255, 255, 255, 0.08)` | 边框 |
| `--color-border-subtle` | `rgba(255, 255, 255, 0.04)` | 弱化边框 |
| `--color-divider` | `rgba(255, 255, 255, 0.06)` | 分割线 |
| `--color-overlay` | `rgba(0, 0, 0, 0.6)` | 遮罩层 |
| `--color-scrim` | `rgba(0, 0, 0, 0.85)` | 深遮罩层 |

### 2.2 字体排版

#### 字体族

| Token | 值 | 用途 |
|-------|------|------|
| `--font-display` | `'Inter', 'Noto Sans SC', system-ui, -apple-system, sans-serif` | 标题与 UI |
| `--font-body` | `'Inter', 'Noto Sans SC', system-ui, -apple-system, sans-serif` | 正文 |
| `--font-mono` | `'SF Mono', 'Fira Code', 'Consolas', monospace` | 等宽数据 |

> 月度日记叙事段首字额外使用 `'Noto Serif SC', Georgia, serif` 作为装饰字体。

#### 字号阶梯

| Token | 值 | 典型用途 |
|-------|------|------|
| `--text-xs` | `0.75rem` (12px) | 标签、时间戳、辅助信息 |
| `--text-sm` | `0.8125rem` (13px) | 正文、按钮文字、分类标签 |
| `--text-base` | `0.9375rem` (15px) | 正文主体 |
| `--text-lg` | `1.125rem` (18px) | 卡片标题 |
| `--text-xl` | `1.375rem` (22px) | 页面标题 |
| `--text-2xl` | `1.75rem` (28px) | 月份选择器标题 |
| `--text-3xl` | `2.25rem` (36px) | AI 分析卡片标题、进度数字 |
| `--text-4xl` | `3rem` (48px) | 首页 Hero 大标题 |

#### 行高

| Token | 值 | 用途 |
|-------|------|------|
| `--leading-tight` | `1.25` | 标题 |
| `--leading-snug` | `1.35` | 副标题 |
| `--leading-normal` | `1.5` | 正文 |
| `--leading-relaxed` | `1.65` | 长文本叙事、AI 描述 |

#### 字间距

| Token | 值 | 用途 |
|-------|------|------|
| `--tracking-tight` | `-0.02em` | 标题 |
| `--tracking-normal` | `0` | 正文 |
| `--tracking-wide` | `0.02em` | 小型大写标签（uppercase labels） |

#### 字重

| Token | 值 | 用途 |
|-------|------|------|
| `--font-weight-light` | `300` | 主标题（Hero、AI 卡片标题） |
| `--font-weight-normal` | `400` | 正文、按钮 |
| `--font-weight-medium` | `500` | 导航、Tab 激活态、CTA |
| `--font-weight-semibold` | `600` | 时间戳、管线步骤标签 |
| `--font-weight-bold` | `700` | （预留，未实际使用） |

### 2.3 间距与圆角

#### 间距阶梯

| Token | 值 |
|-------|------|
| `--space-0` | `0` |
| `--space-1` | `0.25rem` (4px) |
| `--space-2` | `0.5rem` (8px) |
| `--space-3` | `0.75rem` (12px) |
| `--space-4` | `1rem` (16px) |
| `--space-5` | `1.25rem` (20px) |
| `--space-6` | `1.5rem` (24px) |
| `--space-8` | `2rem` (32px) |
| `--space-10` | `2.5rem` (40px) |
| `--space-12` | `3rem` (48px) |
| `--space-16` | `4rem` (64px) |
| `--space-20` | `5rem` (80px) |
| `--space-24` | `6rem` (96px) |
| `--space-32` | `8rem` (128px) |

#### 圆角阶梯

| Token | 值 | 用途 |
|-------|------|------|
| `--radius-sm` | `4px` | 标签圆角、小按钮 |
| `--radius-md` | `8px` | 照片缩略图、小卡片 |
| `--radius-lg` | `12px` | AI 分析卡片、元数据卡片 |
| `--radius-xl` | `16px` | glass-card、主卡片 |
| `--radius-2xl` | `20px` | （预留） |
| `--radius-full` | `9999px` | 药丸按钮、圆点、进度条 |

### 2.4 阴影与动效

#### 阴影阶梯

| Token | 值 | 用途 |
|-------|------|------|
| `--shadow-sm` | `0 1px 2px rgba(0, 0, 0, 0.04)` | 照片网格卡片 |
| `--shadow-md` | `0 2px 8px rgba(0, 0, 0, 0.04)` | 照片详情大图 |
| `--shadow-lg` | `0 8px 24px rgba(0, 0, 0, 0.06)` | （预留，浮动层） |

> 暗色模式阴影透明度提升: sm/md -> 0.3, lg -> 0.4

#### 过渡时间

| Token | 值 | 用途 |
|-------|------|------|
| `--transition-fast` | `150ms ease` | Tab 切换、hover 状态 |
| `--transition-normal` | `250ms ease` | 玻璃面板过渡、导航 |
| `--transition-slow` | `400ms ease` | 主题切换、页面级动画 |

### 2.5 玻璃拟态参数

实现位置：`lib/theme.dart`（`GlassTier` / `GlassSpec` / `GlassColors`）、`lib/components/app_background.dart`。

#### 2.5.1 环境光背景（LV1，必需）

玻璃必须有可模糊的内容。页面背景由 `AppBackground` 统一提供，**任何页面不得再画不透明纯色底**（用 `GlassScaffold`）。

| 层 | 亮色 | 暗色 |
|----|------|------|
| 基底线性 | `#FCFAF6 → #F2F5FA`（左上暖白 → 右下冷白） | `#0B0B10 → #0E0D14` |
| 光斑 A | `#F0CF95` α0.55 @ 左上，r=0.85 | `#3A2A55` α0.55 |
| 光斑 B | `#B9D2F0` α0.50 @ 右侧，r=0.95 | `#12303F` α0.50 |
| 光斑 C | `#EFC9BC` α0.40 @ 左下，r=0.85 | `#3B2A1C` α0.40 |

整体包 `RepaintBoundary`，静态渲染，滚动零重绘。强度可调 `AppBackground(intensity: 1.0)`。

#### 2.5.2 四级玻璃（LV2）

| Tier | 用途 | 亮色填充 | 模糊 | 描边 | 阴影 |
|------|------|---------|------|------|------|
| `thick` | 底部 Sheet、居中对话框 | `rgba(255,255,255,0.86)` | 40 | 白 95% · 0.5px | `0 8 32 rgba(15,23,42,0.08)` |
| `regular` | 导航栏、TabBar、悬浮条 | `rgba(255,255,255,0.72)` | 30 | 白 95% · 0.5px | `0 2 12 rgba(15,23,42,0.05)` |
| `thin` | 内容卡片（`GlassCard` 默认） | `rgba(255,255,255,0.58)` | 无（仿玻璃） | 白 95% · 1px | `0 8 24 rgba(15,23,42,0.07)` |
| `faint` | 卡内次级分组 | `rgba(255,255,255,0.40)` | 无 | 白 60% | 无 |

暗色对应：`thick 88% #16161E` / `regular 白 8%` / `thin 白 8%` / `faint 白 4%`，描边统一白 14%，内高光白 22%。

#### 2.5.3 三条硬规则

1. **内高光 + 底部暗边**：每层必备「顶部 1px 纯白 + 底部 1px 黑 4%（暗色白 10%）」。玻璃的"厚度感"来自这两道边，不是来自透明度——**单纯提高透明度只会让卡片越来越白**。
2. **阴影画在裁剪之外**：`ClipRRect` 之内的 `boxShadow` 会被裁掉，视觉上等于没有阴影。结构必须是 `Container(shadow) → ClipRRect → BackdropFilter → Container(fill+border)`。
3. **只有固定层做真模糊**：`BackdropFilter` 每次都是离屏 `saveLayer`。列表卡片一律走 `thin` 仿玻璃，背后是低频柔光斑，肉眼分不出差别，帧率差一倍。

#### 2.5.4 内嵌面与遮罩

| Token | 亮色 | 暗色 | 用途 |
|-------|------|------|------|
| `surface` | `rgba(255,255,255,0.54)` | `rgba(255,255,255,0.06)` | 输入框、分段控件、图标底座、骨架块 |
| `barrier` | `rgba(0,0,0,0.30)` | `rgba(0,0,0,0.45)` | 弹窗遮罩（配合 thick 玻璃） |

> 禁止用 `#F3F4F6` 这类不透明灰做卡内次级面——它会把玻璃卡"打穿"成实心块，
> 在暖色光斑背景上尤其显脏。

### 2.6 布局常量

| Token | 值 | 用途 |
|-------|------|------|
| `--content-max-width` | `420px` | 页面最大宽度 |
| `--content-padding` | `1.25rem` | 页面水平内边距 |

---

## 3. 页面结构

### 3.1 首页 (Home)

**文件**: `pages/home.html`
**页面类型**: Showcase
**视觉定位**: 杂志封面 — 一张震撼的主视觉图 + 优雅的 AI 标题叠加层 + 充足呼吸感
**构图模式**: 单焦点英雄区 (single-focus-hero)

#### 区域分解

| 区域 | 内容描述 |
|------|------|
| **Hero Section** | 全宽 4:3 比例大图，底部渐变遮罩叠加 AI 标题「六月记忆」+ 副标题「AI 为你精选了 23 张值得珍藏的瞬间」 |
| **最近回忆** | 横向滚动的 88px 正方形缩略图列表，每张标注日期（6月15日、6月12日...） |
| **AI 建议卡片** | glass-card 内含星形图标 + AI 文案「这个月有 5 张截图可以清理，要看看吗？」+ CTA「查看」链接 |
| **AI 状态卡片** | glass-card 内含完成状态圆标 +「AI 分类已完成」+ 进度条文字「32,847 张照片已全部索引」+ 两行增量状态：新增分类 & 后台回顾 |

#### 关键 UI 组件

| 组件 | CSS 类 | 说明 |
|------|------|------|
| 状态栏 | `.status-bar` | 顶部毛玻璃，显示时间 9:41 |
| AI 建议卡 | `.glass-card` | 星形 SVG 图标 + 文字 + CTA 链接 |
| AI 状态卡 | `.glass-card` | 圆形状态图标 + 状态文字 + 增量列表 |
| Tab 栏 | `.tab-bar > .tab-item` | 底部导航，3 个 tab |
| 照片缩略图 | 内联样式 | 88px 正方形，`border-radius: var(--radius-md)` |

#### data-dom-id 导航映射

| data-dom-id | 目标页面 | 标签 | 隐藏连线 |
|-------------|---------|------|---------|
| `tab-home` | page-home | 首页 | 是 |
| `tab-filter` | page-smart-filter | 筛选 | 是 |
| `tab-diary` | page-monthly-diary | 日记 | 是 |
| `cta-diary` | page-monthly-diary | 查看月度日记 | 否 |
| `cta-progress` | page-ai-progress | 查看处理进度 | 否 |

---

### 3.2 月度日记 (Monthly Diary)

**文件**: `pages/monthly-diary.html`
**页面类型**: Showcase
**视觉定位**: 编辑式日记排版 — AI 叙事文字与精选照片交替流动，杂志专栏布局
**构图模式**: 编辑式流 (editorial-flow)

#### 区域分解

| 区域 | 内容描述 |
|------|------|
| **日记头部** | 居中月份选择器「2026年6月」+ 左右箭头 + 副标签「AI 月度日记」+ 分割线 |
| **AI 叙事段** | 段首下沉大字「这」(Noto Serif SC) + AI 撰写的月度总结文字 + AI 徽章标签 |
| **日记条目 1** | glass-card 包含 16:9 照片 + 日期地点「6月15日 · 朝阳公园」+ 斜体 AI 叙述 |
| **日记条目 2** | glass-card 包含渐变占位图 + 日期地点「6月22日 · 三里屯」+ 斜体叙述 |
| **日记条目 3** | glass-card 包含渐变占位图 + 日期地点「6月28日 · 家」+ 斜体叙述 |

#### 关键 UI 组件

| 组件 | CSS 类 | 说明 |
|------|------|------|
| 月份选择器 | 内联 flex | `<` `>` 箭头按钮 + 居中标题 |
| AI 叙事 | 内联样式 + `max-width: 32ch` | 限制行宽，段首下沉字 |
| AI 徽章 | 内联 pill | `border-radius: var(--radius-full)` + `--color-primary-light` 底色 |
| 日记条目 | `.glass-card` | 照片 + 信息区，圆角 overflow-hidden |
| Tab 栏 | `.tab-bar > .tab-item` | 底部导航，当前 tab 为「日记」 |

#### data-dom-id 导航映射

| data-dom-id | 目标页面 | 标签 | 隐藏连线 |
|-------------|---------|------|---------|
| `tab-home` | page-home | 首页 | 是 |
| `tab-filter` | page-smart-filter | 筛选 | 是 |
| `tab-diary` | page-monthly-diary | 日记 | 是 |

---

### 3.3 智能筛选 (Smart Filter)

**文件**: `pages/smart-filter.html`
**页面类型**: Task-driven
**视觉定位**: 干净的图库网格 + 智能分类胶囊 + AI 标签以微透明叠加层形式出现在图片上
**构图模式**: 功能性网格 (functional-grid)

#### 区域分解

| 区域 | 内容描述 |
|------|------|
| **筛选头部** | 页面标题「智能筛选」+ 副标题「AI 已识别 186 张照片」+ 分割线 |
| **分类胶囊** | 横向滚动药丸按钮行：全部(186)、截图(32)、文档(15)、美食(28)、风景(21)、人物(45)、其他(45)。当前选中态为实底填充，未选中态为玻璃背景 |
| **照片网格** | 3 列不规则网格：9 张照片卡片，使用不同 aspect-ratio（1/1、3/5、1/1.15 等），两张大图 span 2 rows。每张卡片左下角浮标 AI 分类标签 |
| **筛选操作栏** | 固定悬浮于 tab 栏上方，毛玻璃背景，左侧「已选 0 张」+ 右侧「清理已选」 |

#### 关键 UI 组件

| 组件 | CSS 类 | 说明 |
|------|------|------|
| 分类胶囊（选中） | 内联样式 | `border-radius: var(--radius-full)`, 实底 `--color-text-primary` |
| 分类胶囊（未选中） | 内联样式 | 玻璃背景 + `backdrop-filter: blur(10px)` |
| 照片网格卡片 | 内联 grid | `grid-template-columns: repeat(3, 1fr)`, `gap: 8px` |
| 分类浮标 | 内联 absolute | `background: rgba(255,255,255,0.85)`, 左下角 6px 偏移 |
| 筛选操作栏 | 内联 fixed | `bottom: 80px`, glass-bg-heavy + blur-heavy |
| Tab 栏 | `.tab-bar > .tab-item` | 当前 tab 为「筛选」 |

#### data-dom-id 导航映射

| data-dom-id | 目标页面 | 标签 | 隐藏连线 |
|-------------|---------|------|---------|
| `tab-home` | page-home | 首页 | 是 |
| `tab-filter` | page-smart-filter | 筛选 | 是 |
| `tab-diary` | page-monthly-diary | 日记 | 是 |
| `card-photo-1` | page-photo-detail | 查看照片详情 | 否 |

---

### 3.4 照片详情 (Photo Detail)

**文件**: `pages/photo-detail.html`
**页面类型**: Detail view (pushed)
**视觉定位**: 沉浸式照片展示 + AI 深度视觉分析面板

#### 区域分解

| 区域 | 内容描述 |
|------|------|
| **Detail Nav** | 固定于 status bar 下方，毛玻璃背景。左侧「返回」按钮 + 右侧「删除」按钮（红色文字）。替代底部 Tab 栏 |
| **照片主图** | 全宽，`max-height: 55vh`, `margin-top: 92px`（status-bar 44 + detail-nav 48），带 shadow-md |
| **AI 深度视觉分析卡** | `.ai-card.glass-card` 包含以下子区域（详见 5.3 节） |
| **照片元数据区** | `.meta-section.glass-card` 包含 4 行键值对：拍摄时间、拍摄地点、文件大小、相似照片 |
| **相似照片区** | 横向滚动缩略图行（80x80px），4 张相似照片 |

#### 关键 UI 组件

| 组件 | CSS 类 | 说明 |
|------|------|------|
| Detail Nav | `.detail-nav` | 固定定位 `top: 44px`, glass-bg + blur |
| 返回按钮 | `.detail-nav__back` | 箭头 SVG + 文字 |
| 操作按钮 | `.detail-nav__action` | 红色删除按钮 |
| 照片大图 | `.photo-hero` | `max-height: 55vh`, `margin-top: 92px` |
| AI 分析卡 | `.ai-card.glass-card` | `border-radius: var(--radius-lg)` |
| AI 标题行 | `.ai-card__title` | sparkle 图标 + 标题 + Vision 徽章 |
| AI 徽章 | `.ai-badge` | pill 形，`--color-primary-light` 底色 |
| AI 标签 | `.ai-tag` | `--active` 实底 / `--inactive` 描边 |
| AI 描述 | `.ai-desc` | 段落文字 |
| 置信度条 | `.confidence-bar > .confidence-bar__fill` | 94% 填充 |
| 元数据行 | `.meta-row` | flex 两端对齐，分割线分隔 |
| 相似缩略图 | `.similar-thumb` | 80x80, `overflow: hidden`, 可点击 |

> **注意**: 此页面没有底部 Tab 栏，由 Detail Nav 替代。

#### data-dom-id 导航映射

| data-dom-id | 目标页面 | 标签 | 隐藏连线 |
|-------------|---------|------|---------|
| `back-filter` | page-smart-filter | 返回筛选 | 是 |
| `similar-photo-1` | page-smart-filter | 查看相似照片 | 是 |

---

### 3.5 AI 处理进度 (AI Progress)

**文件**: `pages/ai-progress.html`
**页面类型**: Status/Monitoring (pushed)
**视觉定位**: 清晰的进度可视化 + 管线步骤分解 + 分类统计

#### 区域分解

| 区域 | 内容描述 |
|------|------|
| **Nav Header** | 顶部固定导航，左侧「返回」+ 右侧「暂停」按钮。背景使用 `--color-bg-elevated`（非玻璃拟态） |
| **进度 Hero** | 居中区域，含扫描模式切换胶囊（首次全量扫描 / 增量更新），下方是 120px 玻璃拟态圆环进度条显示 68%，文字「正在处理 32,847 张照片」+「预计剩余时间 12 分钟」 |
| **处理管线** | 5 步管线垂直列表，每步含：圆形指示器（完成/进行中/等待）+ 名称 + 进度计数 + 描述 + 进度条 |
| **分类统计** | 水平条形图展示已识别的 5 个分类：人物 26%、风景 16%、美食 15%、截图 10%、文档 5% |
| **扫描策略** | glass-card 内含三段式策略说明（首次全量扫描、增量更新、后台回顾） |
| **底部提示** | 居中灰色小字「AI 处理在后台运行，关闭页面不会中断」 |

#### 关键 UI 组件

| 组件 | CSS 类 | 说明 |
|------|------|------|
| Nav Header | `.nav-header` | sticky 定位，`--color-bg-elevated` 背景（非玻璃） |
| 返回按钮 | `.nav-header__back` | 箭头 + 文字 |
| 模式胶囊（选中） | 内联 pill | `--color-primary` 实底 + 闪电 SVG |
| 模式胶囊（未选中） | 内联 pill | `--color-bg-subtle` 底色 |
| 圆环进度 | `.progress-ring` | 120px, 三层结构（bg/fill/inner） |
| 管线步骤 | `.pipeline-step` | flex 布局 + indicator + body |
| 步骤指示器 | `.pipeline-step__indicator` | 三态：completed(绿)/in-progress(主色+动画)/pending(灰) |
| 步骤进度条 | `.pipeline-step__bar` | 6px 高，完成态绿色/进行态主色+脉动动画 |
| 分类行 | `.category-row` | 3 列 grid：标签 + 条形图 + 计数 |
| 扫描策略卡 | `.glass-card` | 包含三个策略项，每项含圆形图标 + 标题 + 描述 |

> **注意**: 此页面使用 `.app-shell--no-tabs` 修饰器，移除底部 padding。

#### data-dom-id 导航映射

| data-dom-id | 目标页面 | 标签 | 隐藏连线 |
|-------------|---------|------|---------|
| `back-home` | page-home | 返回首页 | 是 |

---

## 4. 导航架构

### 4.1 Tab 栏结构

底部 Tab 栏包含 3 个标签页，固定于屏幕底部：

| Tab | data-tab-key | data-dom-id | 图标 | 文字 | 页面 ID |
|-----|-------------|------------|------|------|---------|
| 首页 | `home` | `tab-home` | 房屋 | 首页 | page-home |
| 筛选 | `filter` | `tab-filter` | 漏斗 | 筛选 | page-smart-filter |
| 日记 | `diary` | `tab-diary` | 书本 | 日记 | page-monthly-diary |

**Tab 栏规格**:
- 固定定位 `bottom: 0`, `z-index: 50`
- 玻璃拟态: `glass-bg-heavy` + `glass-blur-heavy`
- 顶部边框: `glass-border`
- 底部 padding: `env(safe-area-inset-bottom) + var(--space-4)`
- Tab 图标: 22x22px, `stroke-width: 1.5`
- 激活态: `--color-text-primary` + `font-weight-medium`
- 非激活态: `--color-text-tertiary`

### 4.2 页面跳转有向图

```
                    ┌──────────────────────────────┐
                    │           page-home           │
                    │     (首页 — Tab 根页面)         │
                    └──────┬───────┬───────┬────────┘
                           │       │       │
                    tab-diary│  tab-filter  │cta-progress
                           │       │       │
                           ▼       ▼       ▼
              ┌──────────┐  ┌──────────────┐  ┌──────────────┐
              │page-     │  │page-smart-   │  │page-ai-      │
              │monthly-  │  │filter        │  │progress      │
              │diary     │  │(智能筛选)     │  │(AI处理进度)   │
              │(月度日记) │  └──────┬───────┘  └──────┬───────┘
              └──────────┘         │card-photo-1      │back-home
                    ▲             │                   │
                    │             ▼                   │
                    │   ┌──────────────────┐          │
                    └───│page-photo-detail  │◄─────────┘
                        │(照片详情)         │
                        └──────┬───────────┘
                               │
                               │back-filter
                               ▼
                        page-smart-filter
                        (返回筛选页)
```

### 4.3 完整跳转表

| 源页面 | data-dom-id | 目标页面 | 跳转类型 | 连线可见 |
|-------|-------------|---------|---------|---------|
| page-home | `tab-home` | page-home | Tab 切换 | 隐藏 |
| page-home | `tab-filter` | page-smart-filter | Tab 切换 | 隐藏 |
| page-home | `tab-diary` | page-monthly-diary | Tab 切换 | 隐藏 |
| page-home | `cta-diary` | page-monthly-diary | CTA 链接 | 可见 |
| page-home | `cta-progress` | page-ai-progress | CTA 链接 | 可见 |
| page-monthly-diary | `tab-home` | page-home | Tab 切换 | 隐藏 |
| page-monthly-diary | `tab-filter` | page-smart-filter | Tab 切换 | 隐藏 |
| page-monthly-diary | `tab-diary` | page-monthly-diary | Tab 切换（当前） | 隐藏 |
| page-smart-filter | `tab-home` | page-home | Tab 切换 | 隐藏 |
| page-smart-filter | `tab-filter` | page-smart-filter | Tab 切换（当前） | 隐藏 |
| page-smart-filter | `tab-diary` | page-monthly-diary | Tab 切换 | 隐藏 |
| page-smart-filter | `card-photo-1` | page-photo-detail | 卡片点击 | 可见 |
| page-photo-detail | `back-filter` | page-smart-filter | 返回按钮 | 隐藏 |
| page-photo-detail | `similar-photo-1` | page-smart-filter | 相似照片点击 | 隐藏 |
| page-ai-progress | `back-home` | page-home | 返回按钮 | 隐藏 |

### 4.4 导航模式分类

| 模式 | 说明 | 示例 |
|------|------|------|
| **Tab 导航** | 底部 Tab 栏切换 3 个主页面，共享 tab-bar | 首页 <-> 筛选 <-> 日记 |
| **CTA 链接** | 页面内链接跳转到子页面 | cta-diary, cta-progress, card-photo-1 |
| **Push 导航** | 子页面 push 入栈，显示 Detail Nav 替代 Tab 栏 | 照片详情、AI 进度 |
| **返回导航** | 子页面返回按钮 pop 出栈 | back-filter, back-home, similar-photo |

---

## 5. AI 处理管线

### 5.1 扫描策略（三段式）

| 阶段 | 名称 | 图标颜色 | 触发条件 | 说明 |
|------|------|---------|---------|------|
| 1 | 首次全量扫描 | 主色 (闪电) | 仅首次打开时执行 | 建立完整索引，处理所有已有照片 |
| 2 | 增量更新 | 绿色 (脉冲) | 日常使用时 | 只扫描新增照片，秒级完成 |
| 3 | 后台回顾 | 蓝色 (月亮) | 充电 + Wi-Fi 时 | 静默重新分析，模型升级后自动触发 |

> 页面进度 Hero 区提供「首次全量扫描」/「增量更新」模式切换胶囊。

### 5.2 视觉分析步骤（5 步管线）

| 步骤 | 名称 | 状态 | 描述 | 子能力 |
|------|------|------|------|--------|
| 1 | EXIF 元数据提取 | 已完成 (100%) | 时间、地点、设备信息 | - |
| 2 | 质量筛选 | 已完成 (100%) | 截图检测、模糊/重复过滤，标记 3,267 张截图 | 截图检测 |
| 3 | 深度视觉识别 | 进行中 (68%) | AI 直接分析画面内容 | 物体检测、场景分类、人脸识别、氛围判断、色彩分析、构图评估、动作识别、文字 OCR |
| 4 | 时间线聚合 | 等待中 (0%) | 按日期/地点聚合，检测特殊事件和出行轨迹 | - |
| 5 | AI 月度日记生成 | 等待中 (0%) | 基于视觉分析结果，LLM 撰写月度记忆叙事 | - |

**管线步骤视觉状态**:
- **已完成**: 绿色圆形指示器 + 白色对勾 SVG, 进度条 100% 绿色填充
- **进行中**: 主色圆形指示器 + 白色圆点 SVG + pulse-ring 动画, 进度条主色填充 + pulse-bar 呼吸动画, 整步使用 glass-card 背景高亮
- **等待中**: 灰色 (`--color-bg-muted`) 圆形指示器（无 SVG）, 进度条 0%

### 5.3 照片详情页 — AI 深度视觉分析

照片详情页的 `.ai-card` 内包含以下 6 个分析维度:

#### (1) 画面场景描述

AI 生成的自然语言场景描述，作为 `.ai-desc` 段落文字。示例:

> 「一张精心摆盘的日式料理特写，木质托盘上摆放着三碟小食，左侧可见握寿司的米粒光泽，中央是一碗味噌汤冒着热气，右侧点缀着腌菜和姜片。暖黄色灯光从左上方投射，在食材表面形成细腻的高光。背景虚化中隐约可见餐厅的榻榻米和障子门。」

#### (2) 物体检测

使用 `.ai-tag` 标签展示:
- **活跃标签** (`.ai-tag--active`): 实底 `--color-primary` 背景 + `--color-text-inverse` 文字 — 表示高置信度识别结果
- **非活跃标签** (`.ai-tag--inactive`): 透明背景 + `--color-border` 描边 + `--color-text-secondary` 文字 — 表示辅助识别结果

示例标签: 握寿司(活跃), 味噌汤(活跃), 木质托盘(非活跃), 腌菜(非活跃), 姜片(非活跃), 筷子(非活跃)

#### (3) 场景与氛围

使用带图标的卡片式标签（`--color-bg-subtle` 背景 + `--radius-md` 圆角），每个含 14px SVG 图标 + 文字。示例:

| 标签 | 图标 |
|------|------|
| 日式餐厅 | 房屋 |
| 暖色调 | 太阳 |
| 晚餐时段 | 时钟 |
| 温馨氛围 | 爱心 |

#### (4) 人物检测

单独区块，`--color-bg-subtle` 背景圆角卡片，含人物图标 SVG + 检测结果文字。

示例: 「未检测到人脸」

#### (5) 主色提取

5 个 40x40px 色块（`--radius-md` 圆角 + `--shadow-sm` 阴影），水平排列。示例色板:

| 色块 | HEX | 名称 |
|------|-----|------|
| 1 | `#8B6914` | 深棕 |
| 2 | `#D4A853` | 暖金 |
| 3 | `#F5E6CC` | 米白 |
| 4 | `#4A6741` | 深绿 |
| 5 | `#2C2418` | 暗木色 |

#### (6) 置信度

整体置信度以百分比文字 + 进度条展示:
- 文字: `.ai-confidence` — 「整体置信度 94%」
- 进度条: `.confidence-bar` (4px 高, `--radius-full`) + `.confidence-bar__fill` (宽度 94%)

---

## 6. 玻璃拟态应用规则

### 6.1 组件使用 glass-card 的情况

| 组件 | 玻璃级别 | blur 值 | 附加样式 |
|------|---------|---------|---------|
| **首页 AI 建议卡** | 标准 | `--glass-blur` (20px) | glass-border-subtle + glass-shadow + glass-inset |
| **首页 AI 状态卡** | 标准 | `--glass-blur` (20px) | 同上 |
| **月度日记条目** | 标准 | `--glass-blur` (20px) | 同上 |
| **照片详情 AI 分析卡** | 标准 | `--glass-blur` (20px) | 同上 |
| **照片详情元数据区** | 标准 | `--glass-blur` (20px) | 同上 |
| **AI 进度扫描策略卡** | 标准 | `--glass-blur` (20px) | 同上 |
| **AI 进度管线进行中步骤** | 标准 | `--glass-blur` (20px) | 同上，边缘到边缘拉伸 |
| **AI 进度圆环** | 标准 | `--glass-blur` (20px) | 外圈 + 内圈均使用 |

### 6.2 导航组件的 blur 级别

| 导航组件 | 玻璃级别 | blur 值 | 背景色 |
|---------|---------|---------|--------|
| **Status Bar** | 标准 | `--glass-blur` (20px / 24px dark) | `--glass-bg` |
| **Detail Nav** | 标准 | `--glass-blur` (20px / 24px dark) | `--glass-bg` |
| **Tab Bar** | 重度 | `--glass-blur-heavy` (40px / 48px dark) | `--glass-bg-heavy` |
| **筛选操作栏** | 重度 | `--glass-blur-heavy` (40px / 48px dark) | `--glass-bg-heavy` |
| **AI 进度 Nav Header** | 无玻璃 | - | `--color-bg-elevated`（实色背景） |

### 6.3 blur 区分原则

- **卡片 (glass-card)**: 使用标准 blur (`--glass-blur`)，确保卡片内容可透过玻璃隐约可见
- **导航栏**: Tab Bar 使用重度 blur (`--glass-blur-heavy`)，因为导航栏需要更强的模糊效果以维持内容可读性
- **子页面导航**: Detail Nav 使用标准 blur，介于 Tab Bar 和卡片之间
- **AI 进度页 Nav Header**: 特例，使用实色背景而非玻璃效果

---

## 7. 暗色模式适配

### 7.1 背景色差异

| 元素 | 亮色 | 暗色 | 变化说明 |
|------|------|------|---------|
| 页面背景 | `#FAFAFA` | `#0C0C0E` | 近白 -> 极深黑 |
| 悬浮背景 | `#FFFFFF` | `#161618` | 纯白 -> 深灰 |
| 次要背景 | `#F3F4F6` | `#1C1C1F` | 浅灰 -> 中灰 |
| 弱化背景 | `#E5E7EB` | `#2A2A2E` | 中灰 -> 较亮灰 |

### 7.2 玻璃效果差异

| Token | 亮色 | 暗色 | 变化说明 |
|-------|------|------|---------|
| glass-bg | `rgba(255,255,255, 0.72)` | `rgba(28,28,31, 0.72)` | 白色玻璃 -> 暗色玻璃 |
| glass-bg-heavy | `rgba(255,255,255, 0.85)` | `rgba(22,22,24, 0.88)` | 更不透明暗色玻璃 |
| glass-blur | `20px` | `24px` | 暗色模式需要更强模糊 |
| glass-blur-heavy | `40px` | `48px` | 同理增强 |
| glass-border | `rgba(255,255,255, 0.3)` | `rgba(255,255,255, 0.1)` | 暗色模式边框更弱 |
| glass-border-subtle | `rgba(255,255,255, 0.15)` | `rgba(255,255,255, 0.05)` | 同理更弱 |
| glass-shadow | `rgba(0,0,0, 0.04)` | `rgba(0,0,0, 0.3)` | 暗色模式阴影更明显 |
| glass-inset | `rgba(255,255,255, 0.5)` | `rgba(255,255,255, 0.08)` | 内高光大幅减弱 |

### 7.3 文字颜色差异

| 层级 | 亮色 | 暗色 |
|------|------|------|
| 主文字 | `#111827` (近黑) | `#F5F5F7` (近白) |
| 次要文字 | `#6B7280` (灰) | `#A1A1AA` (浅灰) |
| 弱化文字 | `#9CA3AF` (浅灰) | `#71717A` (深灰) |
| 反色文字 | `#FFFFFF` | `#0C0C0E` |
| 主色 | `#374151` (深灰) | `#E5E5EA` (浅灰) |

---

## 8. 项目文件结构

```
ai-album/
├── ai-album.design                 # 项目配置与导航连线定义
├── colors_and_type.css              # 设计 Token（色彩、字体、间距、玻璃拟态）
├── orchestration-summary.json      # 页面规划、生成树与接线关系
├── generation-tree.json             # 生成树结构（shell + 页面节点）
├── DESIGN-SPEC.md                   # 本文档 — 完整设计规格
│
├── partials/
│   └── project-shell.html           # 共享布局壳（状态栏 + Tab 栏 + 内容插槽）
│
├── pages/
│   ├── home.html                    # 首页
│   ├── monthly-diary.html           # 月度日记
│   ├── smart-filter.html            # 智能筛选
│   ├── photo-detail.html            # 照片详情
│   └── ai-progress.html             # AI 处理进度
│
└── assets/
    ├── hero-memories.jpg            # 首页 Hero 主视觉
    ├── diary-spring.jpg             # 月度日记配图
    └── photo-detail-food.jpg        # 照片详情配图
```

### 文件用途说明

| 文件 | 用途 |
|------|------|
| `ai-album.design` | SOLO Design 项目元数据，包含页面定义、Canvas 坐标、交互连线、资产清单 |
| `colors_and_type.css` | 品牌设计 Token，通过 `<style id="theme-vars">` 内联到每个 HTML 页面 |
| `orchestration-summary.json` | 编排摘要，记录页面规划（visualNorthStar）、共享 Shell 合约、接线计划、隐藏连线计划 |
| `generation-tree.json` | 生成树 JSON，定义 Shell 和各页面的节点关系、私有区域、可变插槽 |
| `partials/project-shell.html` | 共享布局壳，包含 `.app-shell`、`.status-bar`、`.tab-bar`、`.glass-card` 等 BEM 组件样式 |
| `pages/*.html` | 5 个完整页面，每个页面内嵌完整的 Shell 样式 + Token + 页面特定内容 |
| `assets/*.jpg` | 3 张 JPEG 图片资产，用于 Hero、日记条目和照片详情页 |

---

> **文档结束** — 本规格涵盖 AI 相册的全部设计决策。开发实现时应严格遵循上述 Token 值、组件结构与导航映射。
