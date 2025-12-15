# 构建与部署

本文档介绍如何构建和发布 Music Player 的各平台版本。

## 目录

- [构建前准备](#构建前准备)
- [Windows 构建](#windows-构建)
- [macOS 构建](#macos-构建)
- [Linux 构建](#linux-构建)
- [版本管理](#版本管理)
- [发布流程](#发布流程)

## 构建前准备

### 清理项目

```bash
# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get

# 运行代码分析
flutter analyze

# 运行测试
flutter test
```

### 更新版本号

编辑 `pubspec.yaml`:

```yaml
version: 1.0.0+1
#        ^major.minor.patch+buildNumber
```

版本格式：
- `major`: 主版本号（重大更新）
- `minor`: 次版本号（功能更新）
- `patch`: 补丁号（bug 修复）
- `buildNumber`: 构建号（递增）

### 配置检查

确认以下配置正确：
- 应用名称
- 图标
- 启动画面
- 权限设置

## Windows 构建

### Release 构建

```powershell
# 构建 Release 版本
flutter build windows --release

# 输出目录
# build/windows/runner/Release/
```

### 输出文件

```
build/windows/runner/Release/
├── music_player.exe          # 主程序
├── flutter_windows.dll       # Flutter 引擎
├── data/                     # 资源文件
│   ├── icudtl.dat
│   ├── flutter_assets/
│   └── app.so
└── ... (其他 DLL 依赖)
```

### 创建安装包

#### 使用 Inno Setup

1. 安装 [Inno Setup](https://jrsoftware.org/isinfo.php)

2. 创建安装脚本 `installer.iss`:

```iss
#define MyAppName "Music Player"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Name"
#define MyAppExeName "music_player.exe"

[Setup]
AppId={{YOUR-APP-GUID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=output
OutputBaseFilename=MusicPlayer-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
```

3. 编译安装包:

```powershell
iscc installer.iss
```

#### 使用 MSIX (Windows Store)

```powershell
# 添加 MSIX 支持
flutter pub add msix

# 配置 pubspec.yaml
# msix_config:
#   display_name: Music Player
#   publisher_display_name: Your Name
#   identity_name: com.yourcompany.musicplayer
#   msix_version: 1.0.0.0

# 创建 MSIX 包
flutter pub run msix:create
```

### 代码签名

使用 SignTool 签名：

```powershell
signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com music_player.exe
```

## macOS 构建

### Release 构建

```bash
# 构建 Release 版本
flutter build macos --release

# 输出目录
# build/macos/Build/Products/Release/music_player.app
```

### 应用结构

```
music_player.app/
├── Contents/
│   ├── Info.plist           # 应用信息
│   ├── MacOS/
│   │   └── music_player     # 可执行文件
│   ├── Frameworks/          # Flutter 框架
│   └── Resources/           # 资源文件
```

### 创建 DMG 安装镜像

```bash
# 安装 create-dmg
brew install create-dmg

# 创建 DMG
create-dmg \
  --volname "Music Player" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "music_player.app" 200 190 \
  --hide-extension "music_player.app" \
  --app-drop-link 600 185 \
  "MusicPlayer-1.0.0.dmg" \
  "build/macos/Build/Products/Release/music_player.app"
```

### 代码签名和公证

#### 签名

```bash
# 签名应用
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  build/macos/Build/Products/Release/music_player.app

# 验证签名
codesign --verify --verbose=4 music_player.app
spctl -a -t exec -vv music_player.app
```

#### 公证

```bash
# 创建 ZIP
ditto -c -k --keepParent music_player.app music_player.zip

# 上传公证
xcrun altool --notarize-app \
  --primary-bundle-id "com.yourcompany.musicplayer" \
  --username "your@email.com" \
  --password "@keychain:AC_PASSWORD" \
  --file music_player.zip

# 检查公证状态
xcrun altool --notarization-info REQUEST_UUID \
  --username "your@email.com" \
  --password "@keychain:AC_PASSWORD"

# 装订公证票据
xcrun stapler staple music_player.app
```

## Linux 构建

### Release 构建

```bash
# 构建 Release 版本
flutter build linux --release

# 输出目录
# build/linux/x64/release/bundle/
```

### 输出文件

```
build/linux/x64/release/bundle/
├── music_player              # 可执行文件
├── lib/                      # 共享库
│   ├── libflutter_linux_gtk.so
│   └── ... (其他 .so 文件)
└── data/                     # 资源文件
```

### 创建 AppImage

1. 下载 [appimagetool](https://github.com/AppImage/AppImageKit/releases)

2. 创建 AppDir 结构:

```bash
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/lib
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps

# 复制文件
cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/
cp assets/icon.png AppDir/usr/share/icons/hicolor/256x256/apps/music_player.png
```

3. 创建 desktop 文件 `AppDir/music_player.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Music Player
Exec=music_player
Icon=music_player
Categories=AudioVideo;Audio;
```

4. 生成 AppImage:

```bash
ARCH=x86_64 appimagetool AppDir MusicPlayer-1.0.0-x86_64.AppImage
```

### 创建 DEB 包

1. 创建 debian 控制文件结构:

```bash
mkdir -p debian/DEBIAN
mkdir -p debian/usr/bin
mkdir -p debian/usr/share/applications
mkdir -p debian/usr/share/icons/hicolor/256x256/apps
```

2. 创建 `debian/DEBIAN/control`:

```
Package: music-player
Version: 1.0.0
Architecture: amd64
Maintainer: Your Name <your@email.com>
Description: A cross-platform desktop music player
 Music Player is a feature-rich music player built with Flutter.
Depends: libgtk-3-0, libblkid1, liblzma5
```

3. 复制文件并构建:

```bash
cp -r build/linux/x64/release/bundle/* debian/usr/bin/
cp assets/icon.png debian/usr/share/icons/hicolor/256x256/apps/music_player.png

# 创建 desktop 文件
cat > debian/usr/share/applications/music_player.desktop << EOF
[Desktop Entry]
Type=Application
Name=Music Player
Exec=/usr/bin/music_player
Icon=music_player
Categories=AudioVideo;Audio;
EOF

# 构建 DEB 包
dpkg-deb --build debian music_player_1.0.0_amd64.deb
```

### 创建 RPM 包

使用 `rpmbuild`:

```bash
# 创建 SPEC 文件
cat > music_player.spec << EOF
Name: music-player
Version: 1.0.0
Release: 1
Summary: A cross-platform desktop music player
License: MIT
URL: https://github.com/your-repo/music_player

%description
Music Player is a feature-rich music player built with Flutter.

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps

cp -r build/linux/x64/release/bundle/* %{buildroot}/usr/bin/
cp assets/icon.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/music_player.png

%files
/usr/bin/*
/usr/share/applications/music_player.desktop
/usr/share/icons/hicolor/256x256/apps/music_player.png
EOF

# 构建 RPM
rpmbuild -bb music_player.spec
```

## 版本管理

### Git 标签

```bash
# 创建版本标签
git tag -a v1.0.0 -m "Release version 1.0.0"

# 推送标签
git push origin v1.0.0

# 查看所有标签
git tag -l
```

### 变更日志

维护 `CHANGELOG.md`:

```markdown
# Changelog

## [1.0.0] - 2024-01-01

### Added
- 新增在线音乐搜索功能
- 支持多音乐源
- 添加歌词显示

### Changed
- 优化播放器性能
- 改进 UI 设计

### Fixed
- 修复播放列表bug
- 修复歌词同步问题
```

## 发布流程

### GitHub Release

1. 创建 Release:

```bash
# 通过 GitHub CLI
gh release create v1.0.0 \
  MusicPlayer-Setup-1.0.0.exe \
  MusicPlayer-1.0.0.dmg \
  MusicPlayer-1.0.0-x86_64.AppImage \
  music_player_1.0.0_amd64.deb \
  --title "Version 1.0.0" \
  --notes "Release notes here"
```

2. 或通过 GitHub Web 界面上传

### 自动化构建

#### GitHub Actions

创建 `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.1'
      - run: flutter pub get
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v2
        with:
          name: windows-build
          path: build/windows/runner/Release

  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.1'
      - run: flutter pub get
      - run: flutter build macos --release
      - uses: actions/upload-artifact@v2
        with:
          name: macos-build
          path: build/macos/Build/Products/Release

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.1'
      - run: |
          sudo apt-get update
          sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
      - run: flutter pub get
      - run: flutter build linux --release
      - uses: actions/upload-artifact@v2
        with:
          name: linux-build
          path: build/linux/x64/release/bundle
```

## 检查清单

发布前检查：

- [ ] 更新版本号
- [ ] 更新 CHANGELOG
- [ ] 运行所有测试
- [ ] 代码分析无警告
- [ ] 在目标平台测试
- [ ] 创建 Git 标签
- [ ] 构建所有平台
- [ ] 代码签名（Windows/macOS）
- [ ] 创建安装包
- [ ] 上传到 GitHub Release
- [ ] 更新文档
- [ ] 发布公告

## 相关文档

- [开发指南](./Development-Guide.md)
- [测试指南](./Testing-Guide.md)
- [贡献指南](./Contributing.md)
