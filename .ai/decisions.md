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
