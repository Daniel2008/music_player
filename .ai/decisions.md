# 音乐播放器 需求与决策记录

## 需求池

- 保持本地音乐播放稳定，覆盖添加文件、添加文件夹、播放列表持久化和 M3U 导入导出。
- 优化在线音乐链路，保证搜索、播放 URL 解析、封面、歌词和下载状态有清晰错误提示。
- 完善歌词能力，包括本地同名 `.lrc`、远程歌词缓存、本地歌曲在线歌词匹配和同步滚动。
- 持续完善桌面体验，包括快捷键、窗口控制、全屏可视化、主题皮肤和响应式布局。
- 补充自动化测试覆盖 Provider、模型、API 解析、歌词解析和关键播放列表逻辑。

## 已确认决策

- 使用 Flutter 构建 Windows/macOS/Linux 跨平台桌面应用。
- 使用 Provider / ChangeNotifier 管理全局状态。
- 使用 `flutter_soloud` 作为当前主播放引擎，并从中获取 FFT/波形数据用于可视化。
- 使用 GD 音乐台 API 作为在线搜索、播放链接、歌词和封面来源，API 地址可在设置中配置。
- `Track` 同时支持本地与远程曲目；远程曲目使用 source + trackId 生成确定性 ID。
- 播放列表、设置、收藏、历史、歌词缓存等数据保存在本地应用存储中。
- 不在项目文档或代码中保存 API key、token、password、secret、Authorization、私钥等敏感信息。

## 2026-07-11 代码审查结论

### 工具链阻塞根因

- 项目本身并未持续编译；本机 `D:\worksoft\flutter` SDK 的 `stable` 分支相对远端 `ahead 59 / behind 1473`，且 SDK 内 `pubspec.lock` 有本地修改。
- `D:\worksoft\flutter\bin\cache\flutter_tools.stamp` 内容异常为 `":"`，导致 `flutter.bat` / `dart.bat` 每次启动都尝试重建 Flutter tool snapshot 并长期持有 `flutter.bat.lock`。
- 审查时应临时直接调用 `D:\worksoft\flutter\bin\cache\dart-sdk\bin\dart.exe` 和现有 `flutter_tools.snapshot`；不要并发启动多个 Flutter 包装命令。

### 已确认的代码风险

- `DownloadProvider` 在保存对话框取消时先递减 `_activeDownloads`，`finally` 又递减一次；`removeTask` 和 `clearAll` 也会与下载协程的 `finally` 重复递减，可能令并发计数为负并破坏队列限流。
- `_AppInitializer` 以临时局部变量创建 `SmtcService`，从未调用其 `dispose`；SMTC 对 `PlayerProvider` 的监听和按钮订阅缺少生命周期回收。SMTC 的上一首/下一首处理只移动播放列表索引，没有启动对应音频。
- `PlaylistProvider.init()` 在 Provider 创建时未等待，主界面初始化也不等待它；用户在旧列表加载完成前操作时，异步加载会清空并覆盖内存列表。
- 设置中的“自动搜索本地歌曲歌词”只持久化到 `ApiSettingsProvider`，`PlayerProvider.playTrack` 仍无条件调用 `autoFetchLyricForLocalTrack`，开关当前不生效。
- API 设置重置只重置 Provider 数据，没有同步共享 `GdMusicApiClient` 的 URL/超时，也没有同步 `DownloadProvider.defaultQuality`，运行期会继续使用旧配置直至重启或再次手动修改。
- CI 固定 Flutter 3.27.0，但 `pubspec.yaml` 要求 Dart `^3.10.1`；该 CI 工具链版本与项目 SDK 约束不一致，应统一版本来源。
- `StorageService.writeJsonFile` 注释称有“备份”，实现只有临时文件 rename；读取失败也没有回退备份。测试虽全部通过，但 Favorites/History 测试大量吞掉 Binding 未初始化的存储错误，持久化路径没有被真正验证。

### 本次验证

- 直接 SDK `dart.exe analyze`：通过，无静态分析问题。
- 绕过异常包装脚本直接运行现有 Flutter tool snapshot：63 个测试全部通过。
- 测试日志存在多次 `Binding has not yet been initialized`，均被存储层 catch 后吞掉，因此测试通过不等于持久化功能已覆盖。


## 2026-07-11 缺陷修复与 UI 全面优化

### 已完成修复

- 下载并发槽位改为只在下载协程 `finally` 中归还，保存对话框取消、移除任务和清空任务不再重复递减；增加并发计数回归测试。
- `SmtcService` 纳入 `_AppInitializer` 生命周期并在销毁时释放；Windows 媒体键上一首/下一首现在会切换并实际播放对应歌曲。
- `PlaylistProvider`、`FavoritesProvider`、`HistoryProvider` 暴露 `ready`，主界面显示前统一等待本地数据加载，避免启动阶段覆盖用户操作。
- 本地歌词自动搜索由 `ApiSettingsProvider.autoFetchLyric` 实时控制，关闭后不再发起自动在线歌词匹配。
- API 设置重置会同步共享 API 客户端、请求超时、下载音质和网络检测主机。
- 网络检测主机改为跟随当前 API 地址，不再固定检测默认域名。
- 移除 Windows 全局 `ExcludeSemantics`，恢复屏幕阅读器和自动化语义支持。
- `StorageService` 增加 `.bak` 备份、解析失败回退、写入失败恢复和测试目录注入；Provider 测试使用隔离临时目录，不再靠吞掉 Binding 错误通过。
- CI Flutter 版本从 3.27.0 对齐到项目当前 Flutter 3.41.6 / Dart 3.11.4。

### UI 优化

- 重构全局 Material 3 设计系统：统一页面背景、卡片、输入框、按钮、Chip、列表、滑块、弹窗、底部面板、提示条、滚动条和阴影/边框语义。
- 新增 `AppVisualTheme` 主题扩展，集中管理面板、侧栏、边框和主题光晕颜色。
- 主布局增加响应式导航：宽窗口显示带文字的 220px 侧栏，中等窗口显示紧凑侧栏，窄窗口使用底部导航。
- 主内容加入克制的主题径向光晕；搜索头部改为独立圆角面板；迷你播放器调整间距和圆角，增强层级一致性。
- 收藏、历史、设置等页面的主要留白与头部间距统一。

### 验证

- `dart analyze`：No issues found。
- 绕过本机异常 Flutter 包装脚本运行全量测试：63 项全部通过；增加下载并发测试后定向测试 8 项全部通过。
- 本机 Flutter SDK 包装脚本仍有 stamp/仓库分叉问题，验证继续直接使用 SDK 内 `dart.exe` 和已有 `flutter_tools.snapshot`。


## 2026-07-11 Windows AXTree 兼容回退

- UI 优化后在实际 Windows 运行中复现 Flutter 引擎 `accessibility_bridge.cc(114) Failed to update ui::AXTree` 日志风暴。
- 恢复 `AppRoot` 中仅 Windows 生效的应用级 `ExcludeSemantics`；macOS/Linux 仍保留无障碍语义。
- 这是当前 Flutter Windows 引擎兼容措施，不是业务异常；未来更换干净或更新版 Flutter SDK 后应重新验证并尝试移除。
- 验证：`dart analyze` 无问题，全量 65 项测试通过。

## 2026-09-26 音乐频谱可视化增强

### 数据与绘制

- SoLoud FFT 平滑值从 `0.8` 降至 `0.52`，让鼓点、贝斯和瞬态变化更快进入频谱。
- 频谱数据改为按当前帧峰值进行自适应归一化，并保留带衰减包络；弱信号阈值降至 `0.00008`，低音量不再被过早判为静音。
- 信号增益提高到 `1.8`、压缩指数降至 `0.48`，绘制器统一响应指数降至 `0.50`；柱状基础透明度提高到 `0.76`，同时增强峰值高光和低声部轮廓。
- 曲线、点阵、圆形、波浪、粒子、火焰、雷达、环形、渐变柱和 3D 频谱同步降低二次压缩，提升中低能量下的有效高度与颜色对比。
- 频谱调色板不再直接拼接可能色相接近的主题次色，而是保留主色相并用 `+78°`、`+162°` 生成三种高饱和色；浅色主题统一压暗、深色主题统一提亮，曲线、波浪、雷达、环形和渐变柱同步使用。
- 柱体颜色直接由频率位置决定，不再随柱高混回同一主色，低频、中频和高频的颜色边界更清晰。
- 保持原有 12 种频谱样式、FPS 节流、固定缓冲区和低分配绘制策略，没有新增 Shader/Blur 热循环。

### 验证

- `dart format`：频谱绘制器、可视化和测试文件格式化通过。
- `dart analyze`：No issues found。
- 定向 `test/widget_test.dart`：9 项通过。
- 全量 `flutter test --no-pub --reporter compact`：85 项通过。
- 新增低能量柱体像素测试：4% 能量仍保留超过 34 行高对比像素，防止频谱再次被参数压缩到不可见。
- 新增三频段颜色差测试：三个同高度柱体的实际像素颜色均保持足够距离，防止回退为近似单色。
- 尚未在真实声卡播放场景下做人工视觉验收，也未重新构建 Windows 可执行文件。


## 2026-07-11 全频谱内存与渲染优化

### 根因

- 原 `AnimationController(duration: 33ms).repeat()` 仍按显示器 VSYNC（60/120Hz）回调，Painter 又直接监听 controller，实际并没有限制为 30 FPS。
- 12 种 Painter 中存在单柱/单粒子循环内创建 Gradient、HSLColor、Blur MaskFilter 和临时 Path 的高频分配；粒子与 10 帧历史在非对应样式下也持续维护。
- 全屏按宽度可生成约 100 根柱，3D 历史为 10x128 double，粒子上限 100；PlayerProvider 同时常驻并复制 256 FFT + 256 wave 数据。

### 已完成优化

- 频谱改为独立 `ChangeNotifier` 重绘信号，VSYNC ticker 只负责调度；常规效果严格节流到 30 FPS，重型效果 24 FPS，暂停状态 10 FPS。
- 全屏频谱固定最高 24 FPS并关闭额外 glow；隐藏页面继续由 TickerMode/deactivate 停止。
- 频谱缓冲改为 `Float32List`：最大柱数 72；样式实际柱数常规最多 64、重型最多 48；粒子上限由 100 降至 42；3D 历史由 10 帧降至 5 帧且隔帧写入。
- FFT 对数频段索引预计算为 `Int32List`，热循环不再重复执行频段 `pow/toInt`；PlayerProvider FFT 缓冲由 256 降至 128，并移除未使用的 256 点 wave 缓冲与复制。
- 粒子系统仅在粒子样式运行，3D 历史仅在 3D 样式运行，峰值仅柱状类样式维护；切换其他样式立即清空无关粒子。
- 重写全部 12 种 SpectrumPainter：复用 Paint/Path；取消逐元素 Blur、逐柱 Shader/HSL、临时 Path.from；渐变仅保留每帧少量全局 Shader，发光改为透明高光叠层。
- 为每种样式加入统一性能配置 `isHeavy` / `recommendedBarCount`，并增加覆盖全部样式的性能边界测试。

### 验证

- `dart analyze`：No issues found。
- 全量测试 65 项通过；新增频谱性能配置测试后 widget 定向测试 6 项通过。
- 未启动用户正在运行的应用；实际内存下降幅度需完全重启应用后通过 DevTools/任务管理器对比。


## 2026-09-10 状态隔离、大页面拆分与 API/版本对齐

### 已完成优化

- `PlayerProvider` 增加独立的 `positionNotifier`、`durationNotifier`、`volumeNotifier` 和 `timelineListenable`；100ms 播放位置更新及音量变化不再触发整个 Provider 的重建。
- SMTC、迷你播放器、全屏播放页时间轴改为订阅独立时间轴；`LyricView` 只监听位置变化，不再从 Provider 的全量通知中重复计算歌词行。
- 歌词当前行查询改用 `LrcParser.indexAt` 二分查找，且只在线路变化时更新状态。
- `search_page.dart` 从约 881 行降至 371 行，结果列表及下载/收藏交互拆入 `search_results_view.dart`。
- `settings_page.dart` 从约 1064 行降至 421 行，下载管理、播放设置、外观设置和通用设置组件拆入 `lib/ui/widgets/`。
- 歌词行、空状态和自定义搜索弹窗拆入 `lyric_widgets.dart`，`lyric_view.dart` 保留加载、搜索和滚动协调逻辑。
- 播放列表排序改用当前 Flutter API `onReorderItem`，移除 `PlaylistProvider.reorderTrack` 中旧回调语义所需的 `newIndex -= 1` 调整，并覆盖向上、向下移动测试。
- `pubspec.yaml` 最低版本对齐为 Flutter `>=3.41.0`、Dart `^3.11.0`；README、部署文档和 wiki 已同步，CI 保持 Flutter 3.41.6。

### 验证

- `dart format lib test`：通过。
- `flutter analyze`：No issues found。
- `flutter test`：69 项全部通过。
- `flutter build windows --release`：通过，产物为 `build\windows\x64\runner\Release\music_player.exe`。

### 边界

- 本轮验证覆盖格式化、静态分析、自动化测试和 Windows release 编译，未进行真实播放、音频设备、歌词交互和长时间运行的人工验收。


## 2026-09-10 桌面前端界面重构

### 设计系统

- 新增 `lib/ui/widgets/app_surfaces.dart`，统一 `AppPageHeader`、`AppPanel`、`AppSectionTitle`、`AppMediaRow` 和 `AppEmptyState`。
- 主题改为中性深色背景、低圆角面板和克制边框；卡片、输入框、按钮、弹窗等主要圆角统一到 8px 左右，移除页面级径向光晕和重复装饰阴影。
- 默认主题色调整为松石色，文字字距统一为 0，保留用户已有主题偏好记录。

### 页面重构

- 主壳层精简自定义标题栏、侧栏导航和底部导航，统一导航选中态与窗口按钮。
- 播放页使用新的 `player_workspace_page.dart`：当前曲目概览、封面、播放状态、时间轴，以及“频谱/歌词”视图切换；播放列表保留为右侧常驻面板。
- 搜索页使用统一页头与桌面工具条，搜索结果迁移到固定行高、低动画开销的 `search_results_compact_view.dart`。
- 收藏与历史迁移到 `favorites_workspace_page.dart`、`history_workspace_page.dart`，共用页头、媒体行和空状态。
- 设置页保留全部配置和副作用，仅统一页头、内容宽度与设置面板样式。
- 迷你播放器压缩高度、复用主题面板颜色，并把播放按钮从渐变改为纯主题色。
- 播放队列固定行高由 56px 调整为 60px，避免双行文本和拖拽控件在 `ReorderableListView` 中产生 1px 底部溢出。

### 验证与边界

- `dart format lib test`：通过。
- `flutter analyze`：No issues found。
- `flutter test`：69 项全部通过。
- `flutter build windows --release`：通过。
- 新构建短时启动冒烟测试：进程响应正常并创建 `Music Player` 主窗口。
- 尚未进行完整人工视觉走查、真实播放操作、不同 DPI 和长时间运行验证。


## 2026-09-10 沉浸式播放页重构与内存空转优化

### 界面重构

- 新增 `lib/ui/pages/player_workspace_page_v2.dart`，播放页改为以专辑封面、曲目信息和完整播放控制为中心的沉浸式布局。
- 上一首、播放/暂停、下一首、播放模式、可拖动进度、音量和频谱/歌词切换集中到播放主舞台，不再依赖底部迷你播放器完成主要控制。
- 桌面端播放页隐藏底部迷你播放器，其他页面继续显示；迷你播放器新增 `lib/ui/widgets/mini_player_v2.dart`，移除持续旋转动画并压缩为横向控制条。
- 新增 `lib/ui/widgets/playback_controls.dart`，统一播放按钮、时间轴和音量组件的交互与样式。
- 主布局改为按首次访问懒加载页面，不再在启动时同时构建搜索、收藏、历史和设置页面。
- 移除运行时 Google Fonts 下载调用，中文字体改为系统字体候选链，保留现有主题 API 兼容性。

### 内存根因与优化

- 稳定空载约 340-364MB 的主要来源是 Flutter Windows / D3D / Skia 运行时常驻、系统字体缓存和 `flutter_soloud` native 音频引擎，不是播放列表、封面缓存或 128 点 FFT 数组。
- 启动 3 秒约 470MB 属于资源初始化、着色器和 GC 尚未稳定的瞬时峰值，15 秒后已明显回落。
- `PlayerProvider.pause()` 现在取消 100ms 位置计时器并关闭 SoLoud 可视化采集；`play()` 恢复，`stop()` 和播放完成继续关闭采集。
- `VisualizerView` 在暂停或不可见时完全停止 AnimationController，不再以 10 FPS 维持空闲绘制。
- 播放列表仅在播放中显示动画指示器，暂停时使用静态图标；初始化页完成后停止脉冲动画。

### 验证

- `dart format`：通过。
- `flutter analyze`：No issues found。
- `flutter test`：69 项全部通过。
- `flutter build windows --release`：通过。
- 固定 1280x800 release 采样：3 秒约 472.9MB，15 秒约 327.3MB，48 秒仍为 327.3MB；工作集约较优化前下降 36MB，且 15-48 秒无持续增长。
- 45 秒累计 CPU 时间约 2.4 秒，暂停空载未观察到持续 CPU 轮询。

### 边界

- 当前环境为 150% Windows DPI；自动截图工具对 Flutter D3D 窗口的抓取存在缩放/裁切现象，宽屏和完整队列仍建议在目标显示器上人工确认。
- 未执行真实音频播放、切歌、歌词滚动、全屏频谱、设备切换和数小时稳定性测试。

## 2026-09-23 后续优化审查

### 范围与结论

- 基于当前含大量未提交修改的工作区检查，不回滚已有改动，不修改业务代码。
- 已核实独立播放进度通知、歌词二分查找、暂停停采样、页面懒加载和频谱限帧仍在；下一轮优先可靠性，不重复进行界面重写。
- 以下风险来自静态路径检查，尚未通过真实音频、故障注入或端到端操作复现。

### 建议实施顺序

1. 播放请求一致性：`resolveAndPlayTrackUrl` 在请求返回后读取可变的当前曲目，旧请求可能更新新选中曲目；解析中的新请求又被 `isResolvingUrl` 丢弃。建议在入口绑定曲目 ID 和请求代次，跨 URL 解析、音频加载、停止及销毁统一失效旧请求。
2. 远程播放恢复：`playTrackSmart` 直接复用已保存的 HTTP URL，加载失败没有强制重新解析机制。增加一次有界刷新重试及明确的播放状态，避免过期 URL 持续失败；音质设置应在所有播放入口一致应用。
3. 下载可靠性：当前直接 `openWrite` 最终文件，缺少下载连接/流空闲超时，默认扩展名固定 `.mp3`。使用独立临时文件、完整性与格式检查、成功后落位；取消需覆盖 URL 解析及文件选择等待，并隔离旧协程与重试任务。
4. 保存可靠性：`StorageService` 使用固定 `.tmp/.bak` 路径但没有按文件串行写入，异常仅打印。收藏和历史销毁时取消防抖而不刷新，播放列表销毁时异步保存也不可等待。增加可等待的 flush、关闭前保存、写入结果和并发/损坏恢复测试；现阶段可继续使用本地 JSON。
5. 业务边界：收藏集合仅使用 `track.id`，应改为 `source + id` 并兼容已有数据；清空搜索或搜索空字符串未推进请求代次，旧结果可能回填；删除播放队列当前项之前的条目没有同步减小当前索引。
6. 网络治理：共享 API 客户端构造时没有传入 `isCircuitBroken`，`bindToApiClient` 仅绑定成功/失败回调，熔断状态未真正控制请求入口。补齐接线、重试分类及集成测试。
7. 可测量的性能：播放中 FFT 仍每 100ms 随进度采样，与频谱是否可见无关；歌词订阅也没有页面可见性门控。按可见消费者启停 FFT，评估最小化/后台模式与 SMTC 时间轴通知节流，以相同窗口尺寸和 DPI 实测收益。
8. 维护与验收：核对无引用的旧播放页、旧迷你播放器和依赖后再清理；增加可注入音频引擎及播放竞态测试、真实下载流测试、存储故障测试。CI 配置了测试报告上传路径，但没有显式报告生成步骤。Windows 全局 `ExcludeSemantics` 仍存在，需在复验引擎兼容性后缩小或解除，不能直接删除回退。

### 本轮验证

- 使用已有 Flutter tool snapshot 执行 `test --no-pub --reporter compact`：69 项全部通过。
- SDK 锁文件访问被沙箱阻止后，经提权重试测试成功；工具启动时另有 Flutter Git 标签获取失败警告，不影响本次测试结果。
- 使用 SDK 内 `dart.exe analyze`：No issues found；沙箱内分析器子进程启动被拒绝，经提权重试成功。
- 未重建 release、未启动播放器，未实测内存、CPU、真实播放、弱网、设备切换、不同 DPI 或长时间稳定性；历史性能数据不作为当前测量。

## 2026-09-23 界面与可靠性优化实施

### 已完成

- 统一 Material 3 主题层级：浅色/深色 surface 色板、面板边界、按钮和输入控件风格；减少重复圆角和阴影。
- 播放页、迷你播放器和页面头部增加窄窗口响应式布局；搜索清空按钮、设置保存按钮和工具按钮补齐 tooltip；新增多尺寸浅色/深色布局测试。
- 播放请求增加解析代次和播放代次校验。停止、切歌或目标曲目变化后，旧 URL 返回不会覆盖新曲目；远程 URL 播放失败会重新解析；播放质量统一读取设置。
- 下载任务增加运行代次、取消唤醒、30 秒流空闲超时、`.part` 临时文件和成功后 rename，取消/移除/清空不会提前归还并发槽位。
- JSON 存储按文件名串行写入，保留原子写和备份；修复写入链完成后的 Future 清理；播放列表、收藏、历史提供 flush，应用初始化器退出时主动刷新。
- 收藏键改为 `source + id`；搜索清空使旧请求失效；删除队列条目会同步调整当前索引；网络熔断状态真正接入 API 请求入口，并只对可重试错误重试。
- 频谱仅在存在可见消费者时采样 FFT，并响应 `TickerMode`；不可见页面停止动画和音频采样。

### 验证

- `dart format lib test`：通过。
- `dart analyze`：No issues found。
- 全量 `flutter test --no-pub`：80 项通过。
- 最后一次定向回归：存储、下载、搜索、收藏、播放列表共 28 项通过。
- Windows Release 构建仍被本机 CMake 环境阻断：找不到 `d:/worksoft/Microsoft Visual Studio/18/Professional` 对应的 `Visual Studio 18 2026` 实例；这不是当前 Dart 分析或测试错误。
- 未进行真实音频播放、过期 URL/弱网下载实测、设备切换、人工多 DPI 视觉验收和长时间稳定性测试。

## 2026-09-23 Windows CMake 与 Rust 构建修复

### 根因

- `smtc_windows` 的 Cargokit 初始失败是当前 PowerShell `PATH` 没有包含已有 Rust 工具链目录 `D:\worksoft\.cargo\bin`；设置 `PATH` 和 `CARGO_HOME=D:\worksoft\.cargo` 后，Rust 插件已能成功编译。
- 后续 `INSTALL.vcxproj` 失败的真实原因是 `windows/CMakeLists.txt` 无条件安装 `build/native_assets/windows/`，而本次构建没有生成该目录，导致 CMake 报 `file INSTALL cannot find`。

### 修复

- `windows/CMakeLists.txt` 对 `native_assets/windows` 使用 CMake 的 `OPTIONAL` 安装，安装时若目录不存在则跳过，若配置后生成目录仍可正常复制。
- `docs/deployment.md` 和 `.ai/workflows.md` 补充 Windows Rust PATH/CARGO_HOME 前置配置。

### 验证

- CMake 重新配置：通过。
- 直接执行 `cmake_install.cmake`：通过，Debug Flutter 资源和插件已复制到 `build/windows/x64/runner/Debug`。
- 将安装规则改为 `OPTIONAL` 后重新配置并执行安装：通过；本次原生资产目录已生成，`native_assets.json` 被复制到 Debug 运行目录，验证了配置后生成目录仍能安装。
- Debug 可执行文件启动冒烟：通过，进程保持响应 5 秒后正常结束。
- `dart analyze` 本轮受到 Windows 子进程“拒绝访问”阻断，`flutter test --no-pub` 在 Flutter CLI 没有输出时被停止；此前同一批界面与可靠性改动已记录为分析通过、80 项测试通过。本轮未重新获得测试通过结果。

## 2026-09-23 Windows 插件构建复查

- `smtc_windows` 的 Pub 缓存符号链接目标 `C:\Users\jiang\AppData\Local\Pub\Cache\hosted\pub.flutter-io.cn\smtc_windows-1.1.0` 可读；在 Windows PowerShell 中直接执行 `resolve_symlinks.ps1` 正常退出。用户日志中的 `Get-Item` 错误在当前环境未复现。
- 直接重跑 Cargokit 后，真实错误为 `rustup not found in PATH`。本机 Rust 位于 `D:\worksoft\.cargo\bin`，但默认 PATH 未包含此目录。直接调用 CMake 时还必须有 `FLUTTER_ROOT`；缺少它可能让批处理输出“系统找不到指定的路径”而错误返回成功。
- 新增 `scripts/run_windows.ps1`，自动定位 Rust、检查现有 `smtc_windows` 缓存链接，并在同一进程环境中调用 `flutter run -d windows`；`-CheckOnly` 已通过，找到了 Rust 和 Flutter。
- 从当前工具环境启动完整 Flutter 命令未进入 Dart/MSBuild 阶段且持续无输出，已停止。不能将脚本前置检查或旧 DLL 视作本轮完整构建成功；需在用户本机 PowerShell 执行脚本确认。

## 2026-09-24 小范围可靠性优化

### 修复

- `SearchProvider.searchOnline` 在空关键词分支也推进请求序号，旧请求返回时不会覆盖已清空的结果。
- `DownloadProvider.downloadTrack` 复用同一任务的已有等待 Future，并处理任务在注册等待器前快速结束的边界。
- `PlaylistProvider.addOrSelectTrack` 统一执行 500 首播放列表上限。
- 在线播放链接写回播放列表前同时核对远程 source/id，播放列表已满或当前曲目变化时不会把 URL 写到错误条目。

### 验证

- Dart 静态分析：`No issues found!`
- 定向回归测试：17 项通过。
- 全量 `flutter test --no-pub`：82 项通过。
- 未执行真实音频播放、网络弱网下载、Windows Release 构建和人工多 DPI 视觉验收。

## 2026-09-24 前端与频谱显示优化

### 界面与交互

- 播放工作台的播放舞台、频谱/歌词内容区统一使用面板层级和状态头，窄屏与宽屏保持一致的操作入口。
- 频谱内容区显示当前样式、实时/待机状态，并补充全屏入口。
- 频谱样式菜单使用勾选图标标出当前选项；全屏页上一首/下一首切换后重新读取当前曲目，避免使用旧索引判断。
- 全屏可视化背景改为低对比圆环与网格，不再使用大面积径向渐变；歌词面板收敛为低圆角、低透明度边界。

### 频谱

- 频谱颜色由主题主色、次色和第三色生成三段调色板，柱状频谱自动居中。
- 增加低成本水平参考线、基线、峰值高光和曲线/波形的轻量光晕，保留原有 FPS 与 FFT 消费者节流机制。
- `SpectrumPainter` 新增覆盖全部样式的绘制测试。

### 验证

- Dart 静态分析：`No issues found!`
- 频谱与布局定向测试：14 项通过。
- 全量 `flutter test --no-pub`：83 项通过。
- Windows Debug 构建：通过，产物为 `build/windows/x64/runner/Debug/music_player.exe`。
- 未执行真实音频设备、人工视觉走查和长时间运行测试。

## 2026-09-24 播放工作台浅色界面优化

### 界面调整

- 浅色主题改为更干净的中性背景，页面底色、白色内容面板和边框层级更加清晰，避免截图中的大面积灰蓝融合。
- 播放舞台缩小封面最大尺寸并优化宽屏间距，顶部状态与频谱/歌词/队列控制优先保持单行排列。
- 无封面状态增加明确的音乐图标和“暂无封面”提示，减少大面积空白占位的视觉重量。
- 播放队列宽度和曲目操作间距收紧，保留移除与拖拽入口并提升列表信息密度。

### 验证

- `dart format`：通过，3 个本轮修改文件无需额外格式化。
- `dart analyze`：No issues found。
- 定向 UI 测试：14 项通过。
- 全量 `flutter test --no-pub`：83 项通过。
- 未进行真实音频播放、人工截图复核和不同 DPI 的视觉验收。

## 2026-09-25 整体播放器工作台重构

### 界面调整

- 播放舞台改为顶部完整工具条、下方封面与曲目控制区，避免状态、视图切换和窗口按钮挤在同一行产生横向溢出。
- 封面尺寸上限收敛到 244px，曲目标题、艺人/来源、进度条、播放模式和进度控制改为垂直居中组合，并补回播放页音量控制。
- 宽屏与紧凑舞台共用响应式控制策略；窄控制区自动切换紧凑播放按钮和紧凑音量条。
- 播放队列的移除与拖拽操作默认隐藏，仅在鼠标悬停或当前曲目时显示；操作区宽度改为 76px，消除内部 17px RenderFlex 溢出。

### 验证

- `dart analyze`：No issues found。
- 临时 1600×1000 播放页渲染冒烟：先复现队列溢出的 17px，修复后重新生成预览，无溢出条纹；临时测试和预览文件已清理。
- 全量 `flutter test --no-pub`：83 项通过。
- 本轮未重新构建 Windows 可执行文件，需要在完全重启应用后查看最终视觉效果。

## 2026-09-25 整体界面布局与现代化样式收口

### 设计系统与共享组件

- `AppVisualTheme` 新增 `panelMuted`、`hover`、`selected`、`shadow` 语义令牌，悬停、选中、柔和面板和阴影不再由各页面重复硬编码。
- 全局输入框、按钮、分段控件、弹出菜单和设置列表统一到低圆角、轻边框与紧凑间距；设置项不再直接使用默认 `ListTile` 外观。
- `AppPageHeader`、`AppPanel`、`AppSectionTitle`、`AppMediaRow` 和 `AppEmptyState` 统一缩放页头图标、信息密度、面板层级与列表状态。

### 主壳层与页面
- 自定义标题栏压缩到 48px，侧栏宽度、导航项选中态、图标容器、底部导航和主题按钮统一为同一套圆角与状态色。
- 播放页顶部工具条增加柔和状态面板，宽度不足时自动拆为状态行和控制行，来源文本支持截断，避免再次横向溢出。
- 搜索页工具条收紧留白，筛选器改为统一状态样式并在宽屏左对齐；收藏、历史和搜索列表封面统一为 8px 层级。

### 验证

- `dart format`：通过。
- `dart analyze`：No issues found。
- 全量 `flutter test --no-pub`：83 项通过。
- 响应式 UI 测试：420/900/1280 宽度的浅色与深色主题共 7 项通过。
- 搜索页 420px/1280px 临时渲染截图已人工复核，临时截图目录已清理。
- 未重新构建 Windows 可执行文件，未进行真实音频播放、不同 DPI 和长时间人工视觉验收。

## 2026-09-26 播放页主区重排与底部控制栏固定

### 布局与交互

- 新增 `player_workspace_page_v3.dart`：桌面端主区上方固定为实时频谱，下方为同步歌词，右侧保留可收起播放队列；窄屏按频谱、歌词、队列顺序纵向滚动。
- `main_layout.dart` 切换到 v3，并让 `MiniPlayer` 在播放页始终显示，播放控制固定在窗口内容区最底部。
- 播放页不再保留旧的大封面控制舞台；封面、曲名、进度、播放控制和音量统一由底部 `MiniPlayer` 承担。
- 播放队列操作区由 60px 收紧到 56px，移除/拖拽按钮改为 26x30 紧凑命中区并禁用默认扩展点击热区，消除 1600x1000 布局测试中复现的 20px 横向溢出。

### 验证

- 新增 `test/player_workspace_layout_test.dart`：以 1600x1000 逻辑分辨率验证频谱在歌词上方、歌词在底部控制栏上方，并检查无 RenderFlex 溢出。
- `dart analyze`：No issues found。
- 全量 `flutter test --no-pub --reporter compact`：88 项通过。
- Windows Release 构建通过；1600x1000 播放页截图已生成到 `build/verification/player-workspace-1600x1000.png` 并人工复核。
- 当前桌面为 200% 显示缩放，实机窗口截图会进入窄屏布局；完整桌面比例通过 Flutter 画布测试验证。

### 播放模式按钮修复

- 底栏为减少重建只监听了当前曲目，导致 `cyclePlayMode()` 已修改状态但模式图标和提示文字不刷新。播放模式按钮改为单独监听 `PlaylistProvider`，其余底栏仍保持按曲目选择性重建。
- 布局回归测试增加点击断言：从“列表循环”切换到“单曲循环”后，Provider 状态、工具提示和按钮图标同步更新；全量 88 项测试通过。

## 2026-09-26 播放器界面样式再次收口

### 视觉调整

- 播放页面板标题栏增加轻量背景分层、底部边界线和图标容器，频谱样式以状态胶囊显示，标题栏操作按钮增加低对比背景，提升信息层级。
- 宽屏播放页外边距、频谱与歌词间距、播放队列宽度和歌词区域高度略微收紧，主内容获得更多连续可视空间。
- 底部 `MiniPlayer` 降低垂直内边距，封面从 48px 放大至 52px，保持控制条紧凑的同时提高当前歌曲识别度。
- 本轮只调整布局和视觉样式，没有改变播放、歌词、频谱数据或播放队列逻辑。

### 验证

- `dart format`：通过。
- `dart analyze`：No issues found。
- 播放页 1600x1000 布局回归测试：通过。
- 全量 `flutter test --no-pub --reporter compact`：88 项通过。
- Windows Release 构建成功，`build/windows/x64/runner/Release/data/app.so` 已更新。

## 2026-09-26 全屏频谱铺满、频率响应与歌词避让

### 全屏频谱

- `SpectrumPainter` 新增统一频率布局计算，柱状、点阵、粒子、火焰、渐变柱和 3D 频谱会按画布可用宽度均匀铺开，不再因固定柱宽上限只占据左侧。
- 默认柱宽上限收敛到 28px，重型样式使用 24-28px 上限；宽屏铺满但两侧更留有余量。
- 频谱调色板改为主色相起始的三段高饱和配色，并提高光晕、峰值和低亮度底柱对比度，让低中高频更容易区分。
- FFT 频段映射改为更平缓的指数，加入帧峰值自适应增益；SoLoud FFT 平滑值降至 0.38，上升速度提高到 0.86，瞬态变化更明显。
- 根据第二次实机复核继续下调自适应增益、曲线压缩和高频权重；柱状最高 62%、火焰 68%、渐变柱最高 62%、3D 频谱最高 50%，避免多数频段长期顶满。

### 全屏歌词与布局

- 有歌词时频谱和歌词区域由 6:4 调整为 5:5；全屏频谱启用光晕、关闭参考线并以 30 FPS 运行。
- 歌词面板底部预留 148px 控制栏空间，避免播放进度、按钮和底部渐变压住最后几行歌词。
- 歌词固定行高、上下内边距、激活字号和指示条同步收紧，减少列表滚动估算误差。

### 验证

- `dart format`：通过。
- `dart analyze`：No issues found。
- 定向 `test/widget_test.dart`：11 项通过，包含 1600x500 画布左右两侧均可见、满值柱仍保留顶部空间的回归断言。
- 全量 `flutter test --no-pub --reporter compact`：87 项通过。
- 1600x500 黑底满值渐变柱预览人工复核：左右铺满，顶部约 38% 保持空白。
- 第二次幅度调整后的 Windows Debug 重建被用户中断，现有 exe 尚未包含最新幅度参数。
- 未进行真实音频设备、不同 DPI 和长时间运行的人工视觉验收。

## 2026-09-26 迷你播放器响应式与重建范围优化

### 界面与性能

- `mini_player_v2.dart` 从整条组件监听 `PlayerProvider` 改为按曲目选择性监听，曲目未变化时不再因播放状态或其他播放器通知重建整条底栏。
- 封面状态单独监听 `isPlaying`，时间轴、播放控制和音量继续由各自组件监听对应状态。
- 窄屏底栏保留上下两行结构，桌面宽屏继续按可用宽度显示歌手、播放模式、时间标签和音量。
- 底栏阴影从较强的主色 glow 调整为更克制的主题阴影，减少底部视觉重量。

### 验证

- `dart analyze`：No issues found。
- 全量 `flutter test --no-pub --reporter compact`：83 项通过。
- 迷你播放器格式检查通过。
- 未重新构建 Windows 可执行文件，未进行真实音频播放、不同 DPI 和长时间人工视觉验收。

## 2026-09-26 应用图标统一为浅灰靛蓝音符

### 实现

- 新增 `tool/render_material_app_icon.py`，从 Flutter 自带 MaterialIcons 字体绘制圆角音符图标，配色为背景 `#EAEBF2`、边框 `#C9CBDD`、音符 `#515B92`。
- 同一主稿重新导出 Windows ICO（16/24/32/48/64/128/256）、macOS 全尺寸 AppIcon、Web favicon/普通/maskable 图标和 `assets/branding/` 预览资源。
- Windows Runner 继续引用 `windows/runner/resources/app_icon.ico`，无需修改资源脚本。

### 验证

- `dart analyze`：No issues found。
- 全量 `flutter test --no-pub --reporter compact`：87 项全部通过。
- Windows Release 链接成功；补齐 Rust `PATH`/`CARGO_HOME` 和 `FLUTTER_ROOT` 后重新构建 `smtc_windows.dll`，CMake 安装完成。
- 从 `build/windows/x64/runner/Release/music_player.exe` 反向提取图标，确认浅灰圆角底和靛蓝音符已写入可执行文件。

### 边界

- 用户正在运行的 Debug 进程未终止，当前 Debug 可执行文件仍保留旧图标；重启并重新构建 Debug 后才能使用新图标。
- Release 首次安装失败仅由 Release 版 `smtc_windows.dll` 未生成导致，不是图标资源问题。

## 2026-09-25 播放队列当前曲目操作区收口

### 界面与交互

- 当前曲目不再同时常驻“移除”和“拖拽”两个高对比图标；拖拽手柄在悬停或当前曲目时可见，移除按钮仅在鼠标悬停时出现。
- 两个操作各自使用 28x30 命中区域和 6px 圆角，拖拽区使用抓取光标与轻微悬停底色，移除按钮悬停时使用错误色反馈。
- 保持当前曲目行的选中底色和左侧指示条，不改变播放、删除和重排行为。

### 验证

- `dart analyze`：No issues found。
- 定向 `test/ui_layout_test.dart`：7 项通过。
- 临时 `PlaylistPanel` 截图测试因 `PlayerProvider` 初始化需要 `flutter_soloud` 原生库而无法稳定运行，测试与截图未保留；本次未对真实播放队列进行自动截图验收。

## 2026-09-25 播放热路径与重复实现清理

### 性能与可维护性

- 歌词列表改为固定行高、保留重绘边界，并把滚动调度从旧 `_scrollPending` 收口为单一 `_scrollScheduled`，减少列表测量和重复帧回调。
- 播放工作台从整页 `watch<PlayerProvider>()` 改为 `read`，播放/暂停按钮改为独立的 `_PlayPauseButton` 局部监听，位置与进度更新不再触发舞台大范围重建。
- 删除 6 个已确认无引用的旧实现：`favorites_page.dart`、`history_page.dart`、`player_page.dart`、`player_workspace_page.dart`、`mini_player.dart`、`search_results_view.dart`。
- `.ai/project.md`、`wiki/Architecture.md` 和 `wiki/Development-Guide.md` 已同步到当前页面与组件结构。

### 验证

- `dart analyze`：No issues found。
- 全量 `flutter test --no-pub --reporter compact`：83 项通过。
- 旧实现删除后无生产代码或测试引用，历史决策记录保留不改。
- 未重新构建 Windows 可执行文件，未进行真实音频播放、不同 DPI 和长时间人工视觉验收。
