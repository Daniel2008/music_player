音乐播放器 的项目上下文。

## 产品目标

构建一个基于 Flutter 的跨平台桌面音乐播放器，覆盖 Windows、macOS、Linux 桌面端，提供本地音乐播放、在线音乐搜索/播放、歌词同步、播放列表管理、收藏历史、下载管理、主题皮肤与音频可视化能力。

## 核心页面

- 播放页 PlayerWorkspacePage：上方展示实时频谱，下方展示同步歌词，右侧展示可收起播放队列；完整播放控制条固定在窗口内容区底部。
- 搜索页 SearchPage：按关键词和音乐源搜索在线音乐，支持播放、收藏、下载。
- 收藏页 FavoritesWorkspacePage：管理在线歌曲收藏并快速播放。
- 历史页 HistoryWorkspacePage：查看和清理播放历史。
- 设置页 SettingsPage：配置 API 地址、默认音乐源、播放/下载音质、请求超时、可用音乐源、自动歌词、下载目录、主题皮肤等。
- 全屏可视化页 VisualizerFullscreenPage：展示沉浸式频谱/波形可视化。

## 核心接口与模块

- `GdMusicApiClient`：封装 GD 音乐台 API，负责搜索、专辑搜索、播放 URL、歌词、封面和连通性测试。
- `PlayerProvider`：基于 `flutter_soloud` 管理播放、暂停、停止、跳转、音量、播放错误、FFT/波形数据和远程 URL 解析播放。
- `PlaylistProvider`：管理默认播放列表、当前曲目、播放模式、文件/文件夹添加、M3U 导入导出和本地持久化。
- `SearchProvider`：管理在线搜索状态、结果和竞态保护。
- `DownloadProvider`：管理下载队列、进度、取消、重试和默认保存目录。
- `LyricService`：负责本地同名 `.lrc` 查找、远程歌词缓存、本地歌曲在线歌词匹配。
- `FavoritesProvider` / `HistoryProvider`：分别管理收藏与播放历史持久化。
- `ApiSettingsProvider` / `ThemeProvider`：管理 API、音质、源列表、主题模式与皮肤。

## 业务边界

- 本地播放以用户选择的音频文件/文件夹为输入，支持常见音频扩展名，播放列表上限当前为 500 首。
- 在线能力依赖可配置的 GD 音乐台 API 地址；项目不应依赖本地明文密钥。
- 歌词优先使用同目录同名 `.lrc`，其次使用应用支持目录缓存；在线歌词搜索属于增强能力，失败不应阻塞播放。
- 下载能力以用户配置或默认目录保存在线曲目文件，需展示任务状态并支持取消/重试。

## GitHub 交付与自动构建

- GitHub 仓库：`https://github.com/Daniel2008/music_player`，默认分支为 `main`。
- `.github/workflows/ci.yml` 在任意分支推送或手动触发时运行：Ubuntu 执行 `flutter analyze` 和全量测试，通过后 Windows 执行 release 构建并上传 14 天保留期的构建产物。
- CI 固定 Flutter 3.41.6；播放队列排序必须使用兼容的 `onReorder` 并手动调整向下拖拽索引，不能只依赖 Flutter 3.47 才提供的 `onReorderItem`。
- 跨平台测试中的文件路径不得硬编码 Windows `\`，应使用 `/`、`path` 包或平台路径 API。
- 2026-09-27 推送后的 `main` 和功能分支 GitHub Actions 均通过，Windows 构建产物已成功上传。
- `README.md` 需与仓库地址、功能实现、Actions 状态和路线图保持同步；引用本地文件前必须确认路径存在。
