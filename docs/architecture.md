# 音乐播放器 架构说明

## 总体架构

项目采用 Flutter + Provider 的分层架构：

1. UI 层：`lib/ui/pages` 与 `lib/ui/widgets` 负责页面、导航、播放控件、歌词、可视化、下载/设置等交互。
2. 状态层：`lib/providers` 通过 `ChangeNotifier` 暴露播放器、播放列表、搜索、下载、收藏、历史、主题和 API 设置状态。
3. 服务层：`lib/services` 封装外部音乐 API、歌词缓存和网络连通性检测。
4. 模型层：`lib/models` 与 `GdMusicApiClient` 内的数据类描述曲目、播放列表、搜索结果、播放链接和歌词。
5. 平台层：Flutter 桌面嵌入器、SoLoud 音频引擎、文件选择、窗口管理、快捷键和本地存储插件。

## 模块边界

- `main.dart`：初始化 Flutter、图片缓存、桌面窗口并挂载 `AppRoot`。
- `app.dart`：注册全局 Providers，共享 `GdMusicApiClient`，完成 API 设置、下载音质和播放完成回调初始化。
- `PlayerProvider`：仅负责播放内核状态、SoLoud 生命周期、远程 URL 解析播放、进度/可视化数据和歌词触发。
- `PlaylistProvider`：负责曲目集合、当前索引、播放模式、文件/文件夹添加、M3U 导入导出、播放列表持久化。
- `SearchProvider`：负责搜索状态与结果，不直接处理播放队列。
- `DownloadProvider`：负责下载任务状态机与文件保存。
- `GdMusicApiClient`：负责 HTTP 请求、缓存、重试、超时和响应模型解析。
- `LyricService`：负责歌词来源选择、缓存路径和本地歌曲在线匹配。
- UI 组件：只通过 Provider 调用业务能力，避免直接实现 API/文件持久化逻辑。

## 核心数据流

### 本地音乐播放

用户在播放列表面板添加文件或文件夹 → `PlaylistProvider` 生成 `Track(kind: local)` 并保存 → 用户选中曲目 → `PlayerProvider.playTrackSmart/playTrack` 调用 SoLoud `loadFile` 与 `play` → 定时器更新播放进度、FFT、波形 → `MiniPlayer`、`LyricView`、`VisualizerView` 等 UI 刷新。

### 在线音乐播放

用户在搜索页输入关键词与音乐源 → `SearchProvider.searchOnline` 调用 `GdMusicApiClient.search` → 用户播放搜索结果 → 转换为远程 `Track` 并加入/选中播放列表 → `PlayerProvider.resolveAndPlayTrackUrl` 调用 `GdMusicApiClient.getTrackUrl` → 更新曲目 URL/封面 → SoLoud `loadUrl` 播放 → `LyricService.ensureLyricCachedFor` 异步缓存歌词。

### 歌词显示

`LyricView` 根据当前曲目请求 `LyricService.findExistingLyricPath` → 优先同目录同名 `.lrc`，其次远程/本地缓存 → `LrcParser` 解析时间戳 → 根据 `PlayerProvider.position` 高亮当前歌词。若本地曲目无歌词且设置允许，播放时触发在线搜索并缓存。

### 收藏、历史与下载

- 收藏：搜索结果或收藏页调用 `FavoritesProvider.toggleFavorite`，数据保存到应用支持目录的收藏文件。
- 历史：播放完成回调把当前曲目加入 `HistoryProvider`，历史列表去重并限制长度。
- 下载：用户选择下载搜索结果 → `DownloadProvider` 获取播放 URL → HTTP 流式写入目标文件 → 更新下载任务状态、进度、错误、取消或重试。

## 主要技术栈

- Flutter / Dart
- Provider
- flutter_soloud
- http
- file_picker
- shared_preferences
- path_provider
- window_manager
- hotkey_manager
- cached_network_image / flutter_cache_manager
