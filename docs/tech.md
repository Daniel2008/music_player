# 技术说明

## 架构概览

- 播放内核：`audioplayers`，统一控制播放、暂停、跳转、音量
- 格式与滤镜：`ffmpeg_kit_flutter` 用于将源文件转码为 WAV，并在需要时应用 `equalizer` 滤镜
- 频谱可视化：`flutter_audio_visualizer` 与 `audioplayers` 绑定，实时 FFT 数据展示
- 状态管理：`provider`，包含主题、播放器、播放列表、均衡器等 Provider
- 快捷键：`hotkey_manager` 注册系统级快捷键
- 文件选择：`file_picker` 支持多选
- 历史记录：`shared_preferences` 持久化最近播放

## 关键实现

- 均衡器滤镜串：`equalizer=f=<freq>:t=h:width=<w>:g=<gain>` 多段逗号拼接
- 临时文件：`path_provider.getTemporaryDirectory()` 生成临时 WAV，播放完成后由系统清理
- 频谱样式：`AudioVisualizer` 的 `VisualizationType.spectrum` 与 `AudioVisualizerStyle`
- 歌词同步：`LrcParser` 解析时间戳并在 `position` 流上进行区间匹配

## 跨平台兼容

- Windows/macOS/Linux：依赖 Flutter 桌面嵌入器；FFmpeg 转码在三平台均可用
- 性能优化：WAV PCM 44100Hz/2ch，避免过度滤镜链；UI 降采样条宽与间隔以降低绘制开销
- 内存泄漏检测：建议结合 `DevTools` Memory 观测与 `flutter run --profile` 分析

## 测试

- 单元测试：`test/lrc_parser_test.dart` 验证 LRC 解析
- 兼容性测试：分别使用 `flutter run -d windows|macos|linux` 验证交互
- 性能测试：播放延迟、UI 帧率、转码耗时监控
