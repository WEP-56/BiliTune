# BiliTune UI 设计文档

> 风格定位：Spotify 深色沉浸 + Apple Music 精致排版 + Bilibili 品牌基因

---

## 一、设计理念

### 1.1 三大设计原则

| 原则 | 来源 | 在 BiliTune 中的体现 |
|------|------|---------------------|
| **深色沉浸** | Spotify | 深色背景让专辑封面成为画面唯一的色彩来源；界面本身退居幕后 |
| **精致层级** | Apple Music | 通过排版对比（标题 vs 正文）和表面亮度递增建立层级，不用阴影 |
| **品牌基因** | Bilibili | B站粉色 #FB7299 作为品牌强调色，取代 Spotify Green 的角色 |

### 1.2 核心设计哲学

- **色彩来自内容**：专辑封面是界面的主要色彩来源，UI 本身是"画布"而非"画作"
- **层级通过亮度传达**：深色模式下 `#0A0A0C` → `#16161A` → `#23232A` → `#2E2E36` 逐级提亮，而非叠加阴影
- **一个基元无限扩展**：统一卡片组件，通过形状变化（圆角方形 / 圆形）区分内容类型
- **微交互增强存在感**：200-300ms ease 过渡，opacity + transform 组合驱动所有动画

---

## 二、色彩系统

### 2.1 品牌色

| Token | 色值 | 用途 | 灵感来源 |
|-------|------|------|---------|
| `--color-brand` | `#FB7299` | B站品牌粉：播放按钮、CTA、活跃态 | Bilibili Pink |
| `--color-brand-light` | `#FF8DB1` | 品牌粉亮色变体：hover 态 | Bilibili Pink +20% |
| `--color-brand-dark` | `#D85A80` | 品牌粉暗色变体：pressed 态 | Bilibili Pink -15% |
| `--color-accent` | `#00AEEC` | B站蓝：信息提示、链接、辅助强调 | Bilibili Blue |

### 2.2 表面色阶

| Token | 色值 | 用途 | 对标 Spotify |
|-------|------|------|-------------|
| `--bg-base` | `#0A0A0C` | 基础背景（最深） | `#121212` |
| `--bg-sidebar` | `#010103` | 侧边栏专用背景 | — |
| `--bg-elevated` | `#16161A` | 卡片/二级表面 | `#181818` |
| `--bg-surface` | `#1C1C22` | 悬浮面板/下拉 | `#1A1A1A` |
| `--bg-highlight` | `#23232A` | 悬停态/高亮行 | `#282828` |
| `--bg-active` | `#2E2E36` | 活跃态/选中行 | `#333333` |

> **层级规则**：越亮 = 越高 = 越近用户。深色模式不用阴影，只靠表面亮度差。

### 2.3 文本色阶

| Token | 色值 | 用途 | 对标 Spotify |
|-------|------|------|-------------|
| `--text-primary` | `#FFFFFF` | 标题、歌曲名、主要信息 | `#FFFFFF` |
| `--text-secondary` | `#9E9EAF` | 艺术家名、描述、辅助信息 | `#B3B3B3` |
| `--text-tertiary` | `#6A6A78` | 时间戳、播放数、极弱信息 | `#6A6A6A` |
| `--text-brand` | `#FB7299` | 品牌强调文字 | `#1DB954` |
| `--text-on-brand` | `#FFFFFF` | 品牌色背景上的文字 | — |

### 2.4 语义色

| Token | 色值 | 用途 |
|-------|------|------|
| `--color-success` | `#1ED760` | 成功、已下载、在线 |
| `--color-warning` | `#FFA42B` | 警告、缓存不足 |
| `--color-error` | `#E91429` | 错误、播放失败 |
| `--color-info` | `#00AEEC` | 通知、链接 |

### 2.5 动态提取色

从专辑封面自动提取主色调，用于播放页头部渐变：

```css
.playing-header {
  background: linear-gradient(
    to bottom,
    var(--extracted-color) 0%,    /* 从封面提取 */
    var(--bg-base) 100%           /* 渐变到基础背景 */
  );
  min-height: 340px;
  transition: background 300ms ease;
}
```

提取算法：`Album Art → Dominant Color → Vibrancy Filter → Contrast Check → Gradient Generation`

### 2.6 对比度验证

| 组合 | 对比度 | WCAG 等级 |
|------|--------|----------|
| `#FFFFFF` / `#0A0A0C` | 19.3:1 | AAA ✅ |
| `#FFFFFF` / `#16161A` | 15.1:1 | AAA ✅ |
| `#9E9EAF` / `#0A0A0C` | 6.8:1 | AA ✅ |
| `#9E9EAF` / `#16161A` | 5.3:1 | AA ✅ |
| `#FB7299` / `#0A0A0C` | 5.2:1 | AA ✅ |
| `#6A6A78` / `#0A0A0C` | 3.4:1 | AA-large ⚠️ |

---

## 三、字体排版系统

### 3.1 字体家族

```css
--font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display",
  "Helvetica Neue", "Segoe UI", "PingFang SC", "Noto Sans SC",
  "Microsoft YaHei", Arial, sans-serif;
```

| 平台 | 回退链 |
|------|--------|
| macOS | SF Pro Display → Helvetica Neue |
| Windows | Segoe UI → Microsoft YaHei |
| Android | Noto Sans SC → Roboto |
| Linux | Noto Sans SC → Arial |

### 3.2 排版层级

| 层级 | Token | 字号 | 字重 | 行高 | 字间距 | 用途 |
|------|-------|------|------|------|--------|------|
| **Hero** | `--type-hero` | `48px` | 800 | 1.1 | `-0.03em` | 发现页 Banner 标题 |
| **Title L** | `--type-title-l` | `28px` | 700 | 1.2 | `-0.02em` | 专辑/歌单标题 |
| **Title M** | `--type-title-m` | `22px` | 600 | 1.3 | — | 区域标题、"为你推荐" |
| **Title S** | `--type-title-s` | `16px` | 600 | 1.4 | — | 卡片标题、播放列表名 |
| **Body** | `--type-body` | `14px` | 400 | 1.5 | — | 艺术家名、描述文字 |
| **Caption** | `--type-caption` | `12px` | 400 | 1.4 | — | 时长、播放数 |
| **Overline** | `--type-overline` | `11px` | 500 | 1.4 | `0.06em` | 标签、分类名 |

**核心原则**：
- 粗体紧凑标题 → 创造能量感和视觉冲击
- 弱化常规正文 → 退居幕后不喧宾夺主
- 两极对比建立层级，无需额外视觉元素

### 3.3 中文排版适配

| 规则 | 说明 |
|------|------|
| 字间距 | 中文标题不应用负字间距，仅在英文/数字段落使用 |
| 行高 | 中文正文行高 +4px（1.5 → 1.7），保证可读性 |
| 混排 | 中英文混排时，英文/数字使用等宽对齐（tabular-nums） |

---

## 四、间距系统

### 4.1 基础间距 Token

基于 **4px 基线网格**：

| Token | 数值 | 常见用途 |
|-------|------|---------|
| `--space-1` | `4px` | 图标内边距、紧凑元素间隙 |
| `--space-2` | `8px` | 列表项内间距、图标与文字间隙 |
| `--space-3` | `12px` | 卡片内间距（紧凑模式） |
| `--space-4` | `16px` | 卡片内间距（标准）、列表行间距 |
| `--space-5` | `20px` | 区域标题下间距 |
| `--space-6` | `24px` | 页面边距、大区块间距 |
| `--space-8` | `32px` | 大区域分隔 |
| `--space-10` | `40px` | 页面级边距 |
| `--space-12` | `48px` | Hero 区边距 |

### 4.2 布局间距规范

| 场景 | 数值 |
|------|------|
| 侧边栏内边距 | `12px` |
| 主内容区左右边距 | `24px` |
| 主内容区顶部边距 | `16px` |
| 卡片网格列间距 | `16px` |
| 卡片网格行间距 | `24px` |
| 区域标题与内容间距 | `16px` |
| 区域之间间距 | `32px` |

---

## 五、圆角与形状

| 组件 | 圆角 | 说明 |
|------|------|------|
| 应用窗口（PC） | `12px` | 无边框窗口圆角 |
| 卡片容器 | `8px` | 标准卡片 |
| 卡片封面（专辑/歌单） | `4px` | 方形封面微圆角 |
| 卡片封面（UP主） | `50%` | 圆形头像 |
| 播放按钮 | `50%` | 圆形 |
| 输入框 | `24px` | 胶囊形 |
| Toast / Snackbar | `8px` | — |
| 弹窗 | `12px` | — |
| 迷你播放条 | `8px`（PC）/ 全宽直角（移动） | — |

**形状即类型**：
- **圆角方形** = 专辑、歌单、视频、音频
- **圆形** = UP主、用户头像
- 这一约定深入用户认知，无需标签即可区分

---

## 六、PC 端布局

### 6.1 整体架构：三栏式

```
┌──────────────────────────────────────────────────────┐
│  ◁ ▶ ▸   ← 后退/前进    ···   🔔 👤  │  ← 顶栏 (56px)
├────────┬──────────────────────────┬─────────────────┤
│        │                          │                 │
│  侧边栏 │      主内容区              │  Now Playing    │
│  240px  │      flex: 1             │  可展开/收起      │
│  (可调)  │                          │  默认 320px      │
│        │                          │  (可调)          │
│        │                          │                 │
├────────┴──────────────────────────┴─────────────────┤
│  ▶ ━━━━━━━━━━━━━━━━━━━━━━━━ 3:42/4:15  🔀 🔁 📋 📡  │  ← 播放条 (80px)
└──────────────────────────────────────────────────────┘
```

### 6.2 侧边栏 (240px)

| 区域 | 高度 | 内容 |
|------|------|------|
| 导航菜单 | auto | 🏠 发现音乐 / 🔍 搜索 / 📚 我的音乐 / ⬇️ 下载 |
| 分割线 | 1px | — |
| 播放列表 | flex | 最近播放、收藏夹列表、自建歌单 |
| 底部操作 | auto | ➕ 新建歌单 / 📂 导入歌单 |

**交互**：
- 支持折叠为仅图标模式（64px）
- 播放列表支持拖拽排序
- 筛选按钮：🎵 音频 / 🎬 视频 / 📋 全部
- 侧边栏内搜索框：仅搜索个人库

### 6.3 主内容区

| 页面 | 布局 |
|------|------|
| **发现音乐** | 顶部 Banner → 快捷入口 2×3 网格 → "为你推荐"水平行 → "热门音乐"水平行 → "排行榜"水平行 |
| **搜索** | 搜索框 + 分类标签 + 搜索结果（多 Tab：综合/视频/音频/UP主） |
| **我的音乐** | 双栏：左侧收藏夹列表 + 右侧歌曲列表 |
| **下载管理** | 表格列表 + 存储统计进度条 |
| **设置** | 左右分栏：分类导航 + 设置表单 |

**发现页 Banner**：
- 全宽渐变背景（动态提取色 → 基础背景）
- 高度 `340px`
- 包含：推荐封面 + 标题 + 描述 + 播放按钮

### 6.4 Now Playing 右侧面板

默认收起，点击播放条中的封面图展开：

| 区域 | 内容 |
|------|------|
| 顶部 | 封面图 + 歌曲名 + UP主名 + 操作按钮（❤️ 下载 分享） |
| 中部 | Tab 切换：歌词 / 队列 / 相关 |
| 歌词 Tab | 逐行滚动歌词，当前行高亮放大，品牌色 |
| 队列 Tab | 即将播放列表 + 已播放列表 |
| 相关 Tab | 推荐相似音频 |

### 6.5 播放条 (80px)

```
┌─────────────────────────────────────────────────────┐
│ [封面] 歌曲名 / UP主   ━━━━━●━━━━━  3:42/4:15   🔀 ▶ ⏭ 🔁 📋 📡 🔊━━  │
└─────────────────────────────────────────────────────┘
```

| 区域 | 宽度 | 内容 |
|------|------|------|
| 左 (30%) | flex | 封面 56×56 + 歌曲信息 + ❤️ |
| 中 (40%) | flex | 播放控制 + 进度条 |
| 右 (30%) | flex | 队列 / 循环 / 音量 / 设备 / 展开Now Playing |

### 6.6 窗口规格

| 属性 | 值 |
|------|------|
| 默认窗口 | `1280 × 800` |
| 最小窗口 | `960 × 600` |
| 侧边栏 | `240px`（可调 64~360px） |
| Now Playing | `320px`（可调 0~480px） |
| 播放条高度 | `80px` |
| 顶栏高度 | `56px` |

---

## 七、移动端布局

### 7.1 整体架构：底部 Tab + 迷你播放器

```
┌─────────────────────┐
│    顶部标题栏 48px     │
├─────────────────────┤
│                     │
│    页面内容区         │
│    (可滚动)          │
│                     │
├─────────────────────┤
│  迷你播放器 64px      │  ← 全局悬浮
├────┬────┬────┬──────┤
│ 🏠 │ 🔍 │ 📚 │ 👤   │  ← 底部 Tab 56px
└────┴────┴────┴──────┘
```

### 7.2 底部 Tab 导航

| Tab | 图标 | 页面 |
|-----|------|------|
| 发现 | 🏠 | 首页信息流 |
| 搜索 | 🔍 | 搜索页 |
| 音乐库 | 📚 | 收藏夹 + 歌单 |
| 我的 | 👤 | 个人中心 + 设置 |

### 7.3 迷你播放器 (64px)

```
┌──────────────────────────────────────────┐
│ [封面] 歌曲名 / UP主         ▶  ❤️  ⋮  │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │  ← 细进度条
└──────────────────────────────────────────┘
```

- 顶部 `2px` 品牌色进度条
- 点击整条上滑进入全屏播放器
- 左滑显示删除/下一首快捷操作

### 7.4 全屏播放器

```
┌─────────────────────────────┐
│  ▼ 收起                       │  ← 下拉收起
│                               │
│     ┌───────────────────┐     │
│     │                   │     │
│     │    专辑封面         │     │  ← 大封面，带圆角阴影
│     │    (屏幕宽 - 48px)  │     │
│     │                   │     │
│     └───────────────────┘     │
│                               │
│  歌曲名                   ❤️  │  ← 标题行
│  UP主名                       │
│                               │
│  ━━━━━●━━━━━━━━━━━           │  ← 进度条
│  1:23              3:45       │
│                               │
│    🔀    ⏮    ▶    ⏭    🔁   │  ← 主控制
│                               │
│  📋  📡  ···                   │  ← 队列/设备/更多
│                               │
│  歌词预览（当前行 + 下一行）    │  ← 点击展开歌词全屏
└─────────────────────────────┘
```

**交互手势**：
- 下拉收起 → 回到迷你播放器
- 左右滑动封面 → 切换上一首/下一首
- 歌词区域上滑 → 全屏歌词

### 7.5 移动端页面规格

| 属性 | 值 |
|------|------|
| 顶部标题栏 | `48px` |
| 迷你播放器 | `64px` |
| 底部 Tab | `56px` + 底部安全区 |
| 内容区左右边距 | `16px` |
| 卡片列数 | 2列（< 400px）/ 3列（≥ 400px） |
| 卡片间距 | `12px` |
| 封面圆角 | `8px` |

---

## 八、核心组件规范

### 8.1 内容卡片

**标准卡片**（专辑/歌单/视频/音频）：

```css
.content-card {
  background: var(--bg-elevated);       /* #16161A */
  border-radius: 8px;
  padding: 16px;
  cursor: pointer;
  transition: background-color 200ms ease;
  position: relative;
}

.content-card:hover {
  background: var(--bg-highlight);      /* #23232A */
}

.card-cover {
  width: 100%;
  aspect-ratio: 1;                      /* 1:1 正方形 */
  border-radius: 4px;
  object-fit: cover;
  margin-bottom: 12px;
}

.card-cover--artist {
  border-radius: 50%;                   /* 圆形 = UP主 */
}

.card-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  line-height: 1.4;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-subtitle {
  font-size: 12px;
  color: var(--text-secondary);
  line-height: 1.4;
  margin-top: 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
```

**快捷卡片**（发现页顶部 2 列网格）：

```css
.quick-card {
  display: flex;
  align-items: center;
  background: var(--bg-highlight);
  border-radius: 6px;
  height: 64px;
  overflow: hidden;
}

.quick-card img {
  width: 64px;
  height: 64px;
  object-fit: cover;
}

.quick-card span {
  padding: 0 16px;
  font-size: 14px;
  font-weight: 600;
}
```

### 8.2 播放按钮（悬停浮现）

```css
.play-btn {
  position: absolute;
  bottom: 48px;           /* 相对卡片底部 */
  right: 16px;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: var(--color-brand);    /* #FB7299 */
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transform: translateY(8px);
  transition: opacity 200ms ease, transform 200ms ease;
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.4);
}

.content-card:hover .play-btn {
  opacity: 1;
  transform: translateY(0);
}

.play-btn:hover {
  transform: translateY(0) scale(1.06);
  background: var(--color-brand-light);
}
```

### 8.3 进度条/滑块

```css
.progress-bar {
  width: 100%;
  height: 4px;                       /* 默认 4px */
  border-radius: 2px;
  background: var(--bg-active);
  cursor: pointer;
  position: relative;
}

.progress-bar:hover {
  height: 6px;                       /* 悬停扩展至 6px */
}

.progress-fill {
  height: 100%;
  border-radius: 2px;
  background: var(--text-primary);   /* 默认白色 */
  transition: width 100ms linear;
}

.progress-bar:hover .progress-fill {
  background: var(--color-brand);    /* 悬停变品牌色 */
}

.progress-thumb {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--text-primary);
  position: absolute;
  top: 50%;
  transform: translate(-50%, -50%) scale(0);   /* 默认隐藏 */
  transition: transform 100ms ease;
}

.progress-bar:hover .progress-thumb {
  transform: translate(-50%, -50%) scale(1);   /* 悬停显示 */
}
```

### 8.4 搜索框

```css
.search-input {
  background: var(--bg-highlight);   /* #23232A */
  border: 2px solid transparent;
  border-radius: 24px;               /* 胶囊形 */
  padding: 10px 16px 10px 40px;     /* 左侧留给搜索图标 */
  color: var(--text-primary);
  font-size: 14px;
  transition: border-color 200ms ease, background 200ms ease;
}

.search-input:focus {
  border-color: var(--text-primary);
  background: var(--bg-active);
  outline: none;
}

.search-input::placeholder {
  color: var(--text-tertiary);
}
```

### 8.5 列表行（歌曲列表）

```css
.track-row {
  display: grid;
  grid-template-columns: 32px 48px 1fr 1fr 80px 40px;
  align-items: center;
  gap: 12px;
  padding: 8px 16px;
  border-radius: 4px;
  transition: background-color 150ms ease;
}

.track-row:hover {
  background: var(--bg-highlight);
}

.track-row:hover .track-num {
  display: none;                    /* 序号隐藏 */
}

.track-row:hover .track-play-icon {
  display: flex;                    /* 播放图标显示 */
}

.track-row.playing .track-title {
  color: var(--color-brand);       /* 正在播放 → 品牌色 */
}
```

### 8.6 按钮

| 类型 | 样式 |
|------|------|
| **Primary** | `bg: #FB7299, text: #FFF, radius: 24px, padding: 12px 32px, font-weight: 600` |
| **Secondary** | `bg: transparent, border: 1px #9E9EAF, text: #FFF, radius: 24px` |
| **Ghost** | `bg: transparent, text: #9E9EAF, hover: text #FFF` |
| **Icon** | `48×48, radius: 50%, bg: transparent, hover: bg #23232A` |

---

## 九、动效规范

### 9.1 时长与缓动

| 属性 | 时长 | 缓动函数 | 用途 |
|------|------|---------|------|
| `background-color` | `200ms` | `ease` | 卡片/行悬停 |
| `opacity` | `200ms` | `ease` | 播放按钮出现/消失 |
| `transform` | `200ms` | `ease` | 播放按钮上浮、缩放 |
| `background` (渐变) | `300ms` | `ease` | 专辑头部渐变切换 |
| `width` (进度条) | `100ms` | `linear` | 播放进度推进 |
| `height` (进度条) | `100ms` | `ease` | 悬停扩展高度 |
| 页面切换 | `250ms` | `ease-in-out` | 路由切换淡入淡出 |

### 9.2 动效模式

| 模式 | 实现方式 | 场景 |
|------|---------|------|
| **悬停反馈** | `opacity + translateY` | 卡片播放按钮浮起 |
| **状态切换** | `background-color` 200ms | 行高亮、按钮激活 |
| **页面切换** | `opacity` 淡入淡出 | 路由跳转 |
| **进度推进** | `width` linear | 播放进度条 |
| **弹性反馈** | `scale(1.06)` on hover | 按钮微放大 |

### 9.3 禁止的动效

- ❌ 大范围位移（超过 16px 的 translateX/Y）
- ❌ 3D 旋转/翻转
- ❌ 弹性回弹（bounce easing）
- ❌ 连续循环动画（加载态除外）

---

## 十、图标系统

### 10.1 图标规格

| 属性 | 值 |
|------|------|
| 尺寸 | `24×24`（标准）/ `20×20`（紧凑）/ `32×32`（强调） |
| 线宽 | `1.5px`（标准）/ `2px`（强调） |
| 颜色 | 继承父元素 `currentColor` |
| 风格 | 线性（outline），非填充 |

### 10.2 核心图标清单

| 图标 | 用途 | 位置 |
|------|------|------|
| ▶ / ⏸ | 播放/暂停 | 播放条、卡片、列表行 |
| ⏮ / ⏭ | 上一首/下一首 | 播放条 |
| 🔀 | 随机播放 | 播放条 |
| 🔁 / 🔂 | 列表循环/单曲循环 | 播放条 |
| ❤️ / ➕ | 已喜欢/添加喜欢 | 播放条、列表行、播放器 |
| ⬇️ | 下载 | 列表行、播放器 |
| 📋 | 播放队列 | 播放条 |
| 📡 | 设备连接 | 播放条 |
| 🔊 / 🔇 | 音量 | 播放条 |
| 🏠 | 发现音乐 | 侧边栏/底部Tab |
| 🔍 | 搜索 | 侧边栏/底部Tab |
| 📚 | 音乐库 | 侧边栏/底部Tab |
| 👤 | 个人中心 | 侧边栏/底部Tab |
| 🎵 | 音频类型标识 | 卡片/列表 |
| 🎬 | 视频类型标识 | 卡片/列表 |
| 💬 | 弹幕 | 播放器 |
| 🎤 | 歌词 | 播放器 |

---

## 十一、响应式与自适应

### 11.1 PC 端断点

| 断点 | 宽度 | 布局调整 |
|------|------|---------|
| **Compact** | `960~1099px` | 侧边栏折叠为图标模式(64px)，Now Playing 收起 |
| **Standard** | `1100~1399px` | 标准三栏布局 |
| **Extended** | `≥ 1400px` | 卡片列数 +1，侧边栏/Now Playing 可更宽 |

### 11.2 移动端断点

| 断点 | 宽度 | 布局调整 |
|------|------|---------|
| **Narrow** | `< 360px` | 卡片 2 列，无快捷入口网格 |
| **Standard** | `360~399px` | 卡片 2 列，快捷入口 2×3 网格 |
| **Wide** | `400~599px` | 卡片 3 列 |
| **Tablet** | `≥ 600px` | 两栏布局，类似折叠屏 |

### 11.3 折叠屏适配

| 状态 | 布局 |
|------|------|
| 合盖（外屏） | 标准手机单栏 |
| 展开内屏 | 两栏：左侧导航 + 右侧内容，迷你播放器浮于底部 |
| 横屏展开 | 三栏：类似 PC 端，侧边栏 + 内容 + Now Playing |

---

## 十二、暗色/亮色模式

### 12.1 色彩映射

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| `--bg-base` | `#0A0A0C` | `#F5F5F7` |
| `--bg-sidebar` | `#010103` | `#EFEFF1` |
| `--bg-elevated` | `#16161A` | `#FFFFFF` |
| `--bg-surface` | `#1C1C22` | `#F0F0F2` |
| `--bg-highlight` | `#23232A` | `#E8E8EB` |
| `--bg-active` | `#2E2E36` | `#DCDCDF` |
| `--text-primary` | `#FFFFFF` | `#1D1D1F` |
| `--text-secondary` | `#9E9EAF` | `#6E6E73` |
| `--text-tertiary` | `#6A6A78` | `#8E8E93` |
| `--color-brand` | `#FB7299` | `#E85680` |

### 12.2 亮色模式设计原则

- 亮色模式不使用纯黑 `#000000` 作为文字色
- 表面色层级反转：越浅 = 越高（但仍保持微妙差异）
- 品牌色降低亮度 10% 以保证对比度
- 默认跟随系统，可在设置中切换

---

## 十三、无障碍设计

| 规则 | 实现 |
|------|------|
| 最小触控目标 | 移动端 `44×44px`，桌面端 `32×32px` |
| 焦点指示器 | `2px` 品牌色轮廓，offset `2px` |
| 屏幕阅读器 | 所有交互元素 `aria-label`，封面图 `alt` |
| 键盘导航 | `Tab` 顺序遵循视觉顺序，`Enter/Space` 触发 |
| 对比度 | 正文 ≥ 4.5:1 (AA)，大文本 ≥ 3:1 |
| 减少动效 | `@media (prefers-reduced-motion: reduce)` 禁用所有过渡 |
| 文字缩放 | 布局使用相对单位（rem），支持 200% 放大 |

---

## 十四、页面清单与线框

### 14.1 PC 端页面

| # | 页面 | 路由 | 布局 |
|---|------|------|------|
| 1 | 发现音乐 | `/` | Banner + Shelf 水平行 × N |
| 2 | 搜索 | `/search` | 搜索框 + 热搜 + 结果列表 |
| 3 | 歌单/专辑详情 | `/playlist/:id` | 顶部渐变 + 歌曲列表 |
| 4 | UP主主页 | `/artist/:id` | 封面 + 热门作品 + 全部作品 |
| 5 | 我的音乐 | `/library` | 左右分栏：收藏列表 + 内容 |
| 6 | 下载管理 | `/downloads` | 存储统计 + 下载列表 |
| 7 | 设置 | `/settings` | 分类导航 + 设置表单 |
| 8 | 登录 | `/login` | 居中卡片：二维码/密码/短信 |

### 14.2 移动端页面

| # | 页面 | Tab | 布局 |
|---|------|-----|------|
| 1 | 发现 | 🏠 | 信息流 + Shelf 行 |
| 2 | 搜索 | 🔍 | 搜索框 + 分类 + 结果 |
| 3 | 音乐库 | 📚 | 收藏夹网格 + 最近播放 |
| 4 | 个人中心 | 👤 | 头像 + 设置列表 |
| 5 | 全屏播放器 | — (浮层) | 封面 + 控制 + 歌词 |
| 6 | 歌单详情 | — (子页) | 顶部封面 + 歌曲列表 |
| 7 | 登录 | — (模态) | 全屏登录卡片 |

---

## 十五、与 Spotify / Apple Music 的差异点

### 15.1 BiliTune 特有设计

| 特性 | 说明 | 设计适配 |
|------|------|---------|
| **BV/AV 解析** | 搜索框支持直接粘贴 BV 号 | 搜索结果页增加"智能识别"提示 |
| **弹幕层** | B站特色的弹幕功能 | 播放器增加弹幕开关，半透明浮层 |
| **双类型内容** | 视频(mv) + 音频(audio) | 卡片增加类型图标 🎵🎬，列表增加类型列 |
| **UP主体系** | B站独有的创作者体系 | UP主使用圆形头像（对应艺术家） |
| **音频区** | B站音频区独立内容源 | 搜索/发现中区分"视频音乐"和"音频区" |
| **评论系统** | B站评论区 | 歌曲详情页增加评论区 Tab |
| **关注动态** | 关注UP主的更新 | "发现"页增加"动态"入口 |

### 15.2 不采用的 Spotify 设计

| Spotify 特性 | 不采用原因 |
|-------------|----------|
| 好友动态 | B站社交模式不同，不作为侧边栏常驻 |
| 播客/有声书 | BiliTune 专注音乐，不涉及播客 |
| Spotify Connect | 用 B站跨设备方案替代 |
| Wrapped 年度回顾 | 可作为后续运营功能 |

---

## 附录 A：设计 Token 速查表 (CSS Variables)

```css
:root {
  /* 品牌色 */
  --color-brand: #FB7299;
  --color-brand-light: #FF8DB1;
  --color-brand-dark: #D85A80;
  --color-accent: #00AEEC;

  /* 表面色 */
  --bg-base: #0A0A0C;
  --bg-sidebar: #010103;
  --bg-elevated: #16161A;
  --bg-surface: #1C1C22;
  --bg-highlight: #23232A;
  --bg-active: #2E2E36;

  /* 文本色 */
  --text-primary: #FFFFFF;
  --text-secondary: #9E9EAF;
  --text-tertiary: #6A6A78;
  --text-brand: #FB7299;
  --text-on-brand: #FFFFFF;

  /* 语义色 */
  --color-success: #1ED760;
  --color-warning: #FFA42B;
  --color-error: #E91429;
  --color-info: #00AEEC;

  /* 间距 */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;

  /* 圆角 */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-full: 50%;
  --radius-pill: 24px;

  /* 字号 */
  --type-hero: 48px;
  --type-title-l: 28px;
  --type-title-m: 22px;
  --type-title-s: 16px;
  --type-body: 14px;
  --type-caption: 12px;
  --type-overline: 11px;

  /* 动效 */
  --duration-fast: 150ms;
  --duration-normal: 200ms;
  --duration-slow: 300ms;
  --easing: ease;

  /* 阴影 (仅用于播放按钮等极少数场景) */
  --shadow-float: 0 8px 16px rgba(0, 0, 0, 0.4);
}
```

## 附录 B：Spotify 与 BiliTune Token 对照

| Spotify Token | Spotify 值 | BiliTune Token | BiliTune 值 |
|---------------|-----------|----------------|------------|
| `--essential-positive` | `#1ED760` | `--color-brand` | `#FB7299` |
| `--background-base` | `#121212` | `--bg-base` | `#0A0A0C` |
| `--background-elevated` | `#1A1A1A` | `--bg-elevated` | `#16161A` |
| `--background-highlight` | `#333333` | `--bg-highlight` | `#23232A` |
| `--text-base` | `#FFFFFF` | `--text-primary` | `#FFFFFF` |
| `--text-subdued` | `#B3B3B3` | `--text-secondary` | `#9E9EAF` |

## 附录 C：Apple Music 设计参考点

| 设计元素 | Apple Music 做法 | BiliTune 采用程度 |
|---------|-----------------|------------------|
| 毛玻璃效果 | 侧边栏/播放器大量使用 | ❌ 不采用（性能+风格考量） |
| 大标题排版 | 页面顶部 34pt Bold | ✅ 采用 Hero 层级 |
| 圆角卡片 | 12px 大圆角 | ⚠️ 采用 8px（Spotify 式小圆角） |
| 红色强调色 | `#FC3C44` | → 替换为 B站粉 `#FB7299` |
| 歌词全屏 | 逐行高亮 + 背景模糊 | ✅ 采用，品牌色高亮 |
| 原生导航 | iOS 原生 TabBar | ✅ Flutter 底部 Tab |
