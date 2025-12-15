# 使用文档

## 运行与构建

- 安装 Flutter 并启用桌面支持：`flutter config --enable-windows-desktop --enable-macos-desktop --enable-linux-desktop`
- 拉取依赖：`flutter pub get`
- 运行：`flutter run -d windows` 或其他桌面设备
- 构建：`flutter build windows`、`flutter build macos`、`flutter build linux`

## 基本操作

- 添加歌曲：底部控制区点击“添加歌曲”选择本地文件（支持 MP3/WAV/FLAC/M4A/OGG）
- 播放控制：播放/暂停、上一首、下一首
- 进度拖动：拖动进度条进行跳转
- 音量调节：右侧音量滑块
- 频谱：顶部实时频谱显示，可随主题皮肤变化
- 歌词：自动寻找同名 `.lrc` 文件并同步显示
- 播放列表：右侧列表点击切换当前歌曲
- 主题与皮肤：右上角切换明/暗主题与皮肤方案
- 均衡器：右下角 10 段增益，开启后通过 FFmpeg 离线生效
- 快捷键：空格/媒体键播放暂停、媒体上一首/下一首、Alt+左右方向快进/快退

## 注意事项

- 均衡器为离线处理，切换增益或开启时会对当前音频进行快速转码生成临时 WAV 并播放
- FLAC 等拓展格式在部分平台需要通过 FFmpeg 转码以保证兼容性
