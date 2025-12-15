# Flutter 桌面音乐播放器

跨平台桌面音乐播放器（Windows/macOS/Linux），支持播放/暂停、上一首/下一首、进度拖动、音量调节、频谱可视化、播放列表、主题与皮肤切换、歌词同步、播放历史、均衡器、快捷键。

## 快速开始

- 安装 Flutter 3.38+ 并启用桌面平台
- 在项目根目录执行：`flutter pub get`
- 运行：`flutter run -d windows`（或 `-d macos`、`-d linux`）

## 主要特性

- 音频播放：使用 `audioplayers`，结合 `ffmpeg_kit_flutter` 扩展格式与离线均衡器
- 频谱可视化：`flutter_audio_visualizer`，支持柱状、光谱等样式
- 播放列表与历史：本地文件选择、历史记录保存
- 主题与皮肤：明暗主题切换，自定义皮肤 JSON
- 歌词：LRC 解析与时间同步显示
- 均衡器：10 段增益，FFmpeg 滤镜离线生效
- 快捷键：播放/暂停、切歌、快进/快退

更多使用与技术说明见 `docs/usage.md` 与 `docs/tech.md`。
