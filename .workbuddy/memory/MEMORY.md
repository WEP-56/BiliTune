# BiliTune 项目记忆

## 项目定位
Spotify/Apple Music 风格的 Bilibili 音乐客户端，支持 Windows 和 Android 双端。

## 用户偏好
- 用户倾向使用 Flutter 重写（原 React/RN 方案已搁置）

## 文档
- `docs/参考项目功能汇总.md`: biu + BBPlayer 全功能详细分析
- `docs/B站API使用文档.md`: BiliTune 涉及的所有B站API端点+参数+认证方式
- `docs/BiliTune-UI设计文档.md`: 完整 UI 设计规范 (色彩/排版/间距/布局/组件/动效/响应式/无障碍)

## 技术架构
- **Monorepo**: pnpm workspaces (packages/shared, packages/api, packages/store, apps/desktop, apps/mobile)
- **共享层**: TypeScript 类型/常量/工具 + B站API客户端(WBI签名) + Zustand状态管理
- **PC端**: React 19 + Vite 6 + React Router 7 + Tailwind CSS 4
- **移动端**: React Native 0.85 + Expo 56 + Expo Router

## 参考项目
- biu (Electron桌面端, wood3n)
- BBPlayer (RN移动端, bbplayer-app)
- bilibili-api (Python API封装, Nemo2011)

## CI/CD
- GitHub Actions 自动打包 (`.github/workflows/`)
  - `build-desktop.yml`: Windows NSIS 安装包，electron-builder
  - `build-mobile.yml`: Android APK，`expo prebuild` → `gradlew assemble`，与 Flutter 体验一致
  - `build-all.yml`: 双端一键构建
- Desktop: electron-builder，NSIS/AppImage/DMG
- Mobile: 
  - Debug APK 零配置，直接用 Android debug keystore
  - Release APK 只需在 GitHub Secrets 设三个变量: `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`
- 深色主题: 背景 #0A0A0C, 侧栏 #010103, 表面 #16161A, hover #23232A
- 主色: Bili Pink #FB7299, Bili Blue #00AEEC
- PC: 侧边栏240px + 内容区 + 底部播放栏90px
- Mobile: 底部Tab导航 + 悬浮迷你播放器 + 全屏播放Modal

## 页面 (双端统一)
1. 发现音乐 - Hero Banner + 推荐 + 分类
2. 搜索 - BV/AV解析 + 历史记录
3. 正在播放 - 全屏沉浸 + 歌词 + 弹幕
4. 我的音乐库 - 收藏夹 + 历史 + 关注
5. 下载管理 - 下载状态 + 进度
6. 设置 - 账号/外观/音质/弹幕/缓存
