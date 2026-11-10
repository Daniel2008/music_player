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
- `VisualizerSignal`：将 SoLoud 的 256 点 FFT 转换为对数偏置频段，负责峰值/RMS 混合、攻击/释放平滑、峰值保留和频谱增量节拍检测。
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
- 频谱可视化当前提供 8 种样式；重型样式（粒子、火焰、瀑布谱）默认限制在 30 FPS，新增绘制不得在柱/粒子循环中创建 shader 或模糊对象。
- 2026-09-27 完成频谱升级：完整 256 点 FFT、霓虹分段柱、对数频段、频谱增量节拍检测、瀑布谱和唱片环；`flutter analyze` 与 90 项测试均通过。
- 2026-09-28 精简频谱样式：移除与保留样式视觉重叠的曲线、圆形、雷达、环形、渐变柱和 3D 频谱。
- 自动下一曲不能仅依赖位置定时器轮询；播放器必须监听 flutter_soloud 的 `SoundEventType.handleIsNoMoreValid`，并以播放位置到达时长作为兜底，同时用单个完成处理标志和当前句柄校验防止重复切歌或过期事件。
- 唱片环不能用整盘 `RadialGradient` 实心填充，否则会退化成球体观感；外盘应使用描边轮廓，中心只保留小孔和拍点环。
- 紧凑播放队列的右侧操作区至少保留 68px；移除与拖拽控件各占 28px，并用 10px 间距隔离，避免图标拥挤重叠。
- 2026-10-01 频谱继续优化：PlayerProvider 同时读取 SoLoud 的 256 点 FFT 与 256 点真实 waveform；VisualizerFrame 统一缓存波形、频谱和瀑布历史，SpectrumPainter 使用真实波形绘制 wave 样式。
- 2026-10-01 频谱信号增加动态范围自适应、峰值保持、低/中/高频能量和节拍响应；火焰按频段摆动并铺满宽屏，瀑布谱按历史年龄衰减，唱片环增加扫光和低频轻微缩放。
- 2026-10-01 新增 VisualizerSettingsProvider，持久化灵敏度、平滑度、发光强度、背景透明度和刷新率上限；设置页提供对应控件，普通播放页与全屏页共享配置。
- 2026-10-01 修复频谱不显示风险：可视化布局变化时主动同步 consumer，采样使用播放器真实 isPlaying 状态，SoLoud 初始化改为幂等 Future，FFT/波形读取异常时清空缓存。
- 2026-10-01 修复暂停/切页后的频谱残留：停止动画时重置信号、波形、瀑布历史和粒子；全屏频谱继承播放页当前样式；可视化设置保存改为 250ms 防抖并防止加载竞态。
- 2026-10-01 锁定 `flutter_rust_bridge: 2.11.1`：`smtc_windows 1.1.0` 的 codegen 版本为 2.11.1，pub 上没有版本声明匹配它的更新包，因此必须在 `pubspec.yaml` 用 `dependency_overrides` 固定 2.11.1，否则运行时会打印 codegen/runtime 版本不一致告警（该告警会被 SmtcService 捕获，不阻塞播放）。
- 2026-10-01 播放健壮性：`PlayerProvider.playTrack` 在调用 `SoLoud.loadFile` 前先校验本地文件是否存在，因为文件缺失时 C++ 侧抛出的 `SoLoudFileNotFoundException` 无法被 Dart `try/catch` 捕获，会在应用日志里留下未处理异常；缺失文件应只设置 `playError` 并返回 false，且不要打断当前正在播放的曲目。
- 2026-10-01 `playTrackSmart` 返回值改为 `Future<bool>`（表示是否成功播放），调用方可在失败时继续决策。
- 2026-10-01 `PlayerProvider._listenForCompletion` 的 `soundEvents` 订阅必须提供 `onError`，否则原生事件流错误会变成未处理异常；播放结束检测由事件流与位置定时器双重兜底。
- 2026-10-01 `PlayerProvider.dispose` 不再直接调用 `disposeSource` + `deinit`，而是按 `stop` → `disposeSource` → `deinit` 的顺序串行释放（`_disposeAudioResources`），避免与 native 释放竞争导致崩溃或资源泄漏。
- 2026-10-01 自动下一曲：`onTrackComplete` 回调在切换后按播放列表长度封顶重试，跳过无法播放的曲目（例如文件已被移动）；顺序模式到达末尾时 `next()` 不移动索引，必须据此退出重试循环，避免死循环。
- 本机 Flutter 工具链注意事项：`flutter.bat`/`dart.bat` 需要写入 `D:\worksoft\flutter\bin\cache\flutter.bat.lock` 并在失败时静默无限重试；该目录不在工作区写入白名单内，因此沙箱内运行 flutter 命令会空转，必须在沙箱外执行。
- 播放失败必须可见：`PlayerProvider.playError` 原先只在收藏页/搜索结果展示，播放列表面板与播放控制条点击后没有任何反馈（表现像“点了没反应”）。现在两者都会用 SnackBar 报出 `playError`。
- 2026-10-01 排查“无法播放”：根因是本地曲库目录 `E:\音乐` 已不存在（E: 盘正常，目录消失），持久化播放列表里 373 首本地曲目路径全部失效，与应用代码无关。诊断方法：`%APPDATA%\com.example\music_player\saved_playlist` 是版本化 JSON（`_v` + `data.tracks`），可直接校验每个 `path` 是否存在。
- 回归验证提示：`flutter run -d windows` 的日志可确认 `SmtcService 初始化完成`（说明 frb 2.11.1 已使 SMTC 真正生效）且无 `SoLoud 初始化失败`，音频引擎本身正常。
- 2026-10-01 修复全屏可视化浅色主题：`VisualizerFullscreenPage` 原先将 Scaffold、动态背景、歌词面板、控制栏渐变、按钮文字和样式选择器多处写死为黑/白色，导致全屏永远呈现黑色主题。现在统一使用 `ColorScheme.surface`、`surfaceContainerHigh`、`onSurface`、`onSurfaceVariant` 和 `outlineVariant`，背景网格绘制器也根据主题切换线条颜色；深色主题仍保留原有沉浸式黑底效果。
- 2026-10-01 频谱动态层优化：`SpectrumPainter` 在绘制各样式前增加低分配节拍脉冲层，按 beat intensity 在基线/中心线生成轻微亮度反馈；霓虹柱峰值标记改为调色板高亮并增加受 `glowStrength` 控制的柔和光晕，减少白色横线突兀感，同时不改变现有 8 种样式和刷新率策略。
- 2026-10-01 火焰样式强化：火焰不再是浅色三角柱；`_paintFlame` 现在使用深橙外焰、黄白内焰、底部渐隐火光、按相位变化的火舌摆动和少量上升火星。火焰样式隐藏通用网格线，静音时自动收起，浅色主题下保持更高对比度；仍只复用已有 Paint/Path，未在每个火舌内创建模糊对象。
- 2026-10-01 频谱铺满与全屏一致性：普通柱状频谱最大高度由 68% 提升到 88%，镜像柱由单侧 30% 提升到 43%，减少容器上方空白；全屏频谱统一使用播放页的 10px 横向/8px 底部内边距并显示参考线。`VisualizerFullscreenPage` 新增 `onStyleChanged`，全屏切换样式会回传给 v2/v3 播放页，避免进入全屏或返回后样式状态不一致。
- 2026-10-01 瀑布谱重做：去掉通用参考线，频段使用相邻值平滑，历史单元改为带圆角和间距的流带，按时间年龄衰减亮度；新增最新一帧的平滑轮廓线和轻微光晕，让瀑布谱具有清晰的当前边缘和连续流动感。绘制仍复用单个 Paint/Path，不在单元循环中创建 shader。
- 2026-10-06 界面响应式优化：中等宽度的底部播放器改为曲目信息/控制与进度条两行布局，避免时间轴被控制按钮挤压；音量控件延后到更宽窗口显示；播放页窄屏的频谱、歌词和播放队列高度按可用宽度自适应；频谱面板标题与样式标签增加省略约束，减少小窗口下的控件拥挤。
- 2026-10-06 频谱动态层增强：不新增重复样式，在 `SpectrumPainter` 中为柱状/镜像频谱加入连续能量轮廓线，为轻量样式加入低透明度扫描光束，为唱片环加入节拍扩散环；所有新增绘制复用现有 `Paint/Path`，并通过相位变化测试验证动态画面确实更新。

## 界面材质与频谱展示约定（2026-10-21）

- `TexturedSurface`（`lib/ui/widgets/surface_texture.dart`）提供 grain / woven / brushed 三种主题感知静态纹理；放在独立 RepaintBoundary，避免随频谱动画重绘，歌词阅读区保持干净背景。
- 播放页采用渐变频谱舞台、单一样式选择入口与独立状态栏，待机使用静态唱片插画；保留八种频谱及已有音频处理和刷新率策略。
- SpectrumPainter 的背景特效与主体绘制之间必须重置 Paint，shader 绘制前显式设置适当的 Paint.color alpha，避免描边或透明度状态泄漏。
- 视觉验证：`test/player_workspace_layout_test.dart` 覆盖 360 / 820 / 1040 / 1600 内容宽度与深浅主题，`test/spectrum_rendering_test.dart` 覆盖频谱渲染；设置 UI_CAPTURE_DIR 可输出预览，合成预览不代表真实音频验收。

## 应用审查（2026-10-23）

- 本轮只审查当前工作区，保留全部既有未提交改动，未修改业务代码。当前验证：`dart analyze` 无问题；`flutter test --no-pub --reporter expanded` 共 103 项通过。沙箱内 Flutter SDK 锁文件和分析子进程受限，改用受控权限执行后通过。
- 优先修复：下载按歌名/歌手拼目标路径，不同任务可能共享 `.part`，完成时先删除已有目标文件；本地播放在异步文件存在性检查和 stop 之后才分配请求代次，旧请求可能覆盖新选择；窗口直接 close，保存仅在 dispose 中 unawaited，未保证退出前落盘。
- 存储恢复：空文件、有效 JSON 但结构不符、decode 失败没有统一回退 `.bak`；写入失败只打印日志，调用方无法报告保存失败。
- 设置与体验：下载目录/并发数/自动开始仅保存在内存，后两者直接改字段未通知界面；关闭自动开始后管理面板无等待任务的开始入口。清除歌词缓存只清内存 Map，不删除磁盘文件，也不更新歌词版本。
- 播放入口一致性：全局播放快捷键仅在 current.path 为空时首次加载，已有本地路径或缓存远程 URL 且无 handle 时无法启动；单曲循环直接 playTrack，未复用 playTrackSmart 的远程地址刷新路径。
- 精简候选：`lib/ui/pages/player_workspace_page_v2.dart`（871 行）和 `lib/audio/ffmpeg_transcoder.dart`（57 行）当前源码无调用，后续删除前再次核对引用与历史用途。
- 尚未执行真实音频、同名并发下载、快速关窗、长期 CPU/GPU/内存、多 DPI 与 macOS/Linux 验收。上述边界问题为代码路径审查结论，不能以 103 项现有测试通过视为已排除。

## 可靠性修复与性能复测（2026-10-23）

- 用户确认两组都处理，先可靠性后绘制/内存。已修复同名并发下载覆盖、播放请求竞态、退出等待保存、备份恢复和写错误传播、下载设置持久化、歌词磁盘缓存清理、各播放入口智能加载；移除无调用旧页面/转码器。保留原始 WIP，未提交、推送、部署。
- 测试使用隔离存储，真实本地 HTTP 验证下载内容和已有文件保留；播放在 SoLoud 边界注入测试替身，覆盖异步本地检查、旧原生加载与新 URL 请求的交错；窗口关闭用插件通道测试等待、失败和重试。完整 122 项通过，dart analyze 无问题，Windows Profile 构建成功。
- 关闭前停止播放、屏蔽界面编辑并等待 playlist/history/favorites/download 设置保存；并发 settings flush 必须等待最新 pending 身份，不能只等旧 Future 后检查 dirty。该竞态已由阻塞 latest 写入的测试先复现再修复，指定范围复查通过。
- 旧 v2 页原有局部修改保存在 docs/legacy-player-workspace-v2.patch，完整副本 build/verification/player_workspace_page_v2.pre-removal.dart；不得作为无关 WIP 丢弃。文档 docs/reliability-performance-fixes-2026-10-23.md、执行计划 docs/superpowers/plans/2026-10-23-reliability-performance.md。
- 性能：独立 quick Profile 入口使用合成 600 秒音频、500 队列、隔离偏好与数据目录；前台控制组 build/verification/performance-desktop-control，在 150% DPI 下霓虹柱/瀑布谱/全屏栅格 P95 27.57/28.09/22.08ms。原始 35–40ms 报告存在环境波动，不可直接当优化收益基线。
- 绘制试验：动态频谱独立 RepaintBoundary、willChange；瀑布谱缓存单元几何并合并重复幂计算，已有尺寸变更与数据更新测试。优化后第一次运行因窗口最小化无效，build/verification/performance-after 不可用于收益结论。Computer Use 恢复持续被“user input was detected”/“window is minimized”拦截，已暂停 UI 操作并请用户恢复窗口后继续；性能阶段尚未完成。
- 内存：控制组 Dart 堆约 31MiB、进程 RSS 约 951MiB；另一轮最小化运行频谱阶段堆约 19MiB、RSS 约 859MiB。不能把 RSS 直接认定 Dart 泄漏；采样缓冲已改为首次可视化才创建。长期稳定性、Release、多 DPI 与其他桌面平台待验收。
- 后续用户恢复窗口，前台有效复测已完成：build/verification/performance-after（7 阶段，119 进程样本、109 GPU 样本，Flutter 错误 0）；无效最小化数据移至 performance-after-minimized。普通窗口 1904×1191、全屏 2560×1600、DPI 1.5，与控制一致。霓虹柱/瀑布谱/全屏栅格 P95 23.579/24.620/19.816ms，比控制低 14.5%/12.3%/10.3%，但 CPU/GPU 均值未下降。保留绘制改动，只声称本轮尾延迟改善。
- 进程采样峰值 RSS 1347.9→1272.3MiB；闲置采样峰值 1020.7→989.3MiB，应用内阶段末尾 RSS 950.2→921.8MiB，采样点不同不要混用。优化后闲置 Dart 堆 23.7MiB。暂停 15 秒仅 1 帧，闲置 CPU 0.09%、GPU 最忙引擎 0.12%。内存高占用未根治、60fps 未达标，后续应长时间分析原生图形资源分配，不靠强制 GC 猜测泄漏。
