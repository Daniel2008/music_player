import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:window_size/window_size.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'dart:io';
import 'music_player_state.dart';
import 'audio_visualizer.dart';
import 'playlist_view.dart';
import 'lyrics_view.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 添加这一行

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('音乐播放器');
    setWindowMinSize(const Size(800, 600));
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => MusicPlayerState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '音乐播放器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const MusicPlayerHome(),
    );
  }
}

class MusicPlayerHome extends StatefulWidget {
  const MusicPlayerHome({super.key});

  @override
  State<MusicPlayerHome> createState() => _MusicPlayerHomeState();
}

class Song {
  final String path;
  final String title;
  
  Song({required this.path, required this.title});
  
  factory Song.fromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final title = fileName.split('.').first;
    return Song(path: path, title: title);
  }
}

class _MusicPlayerHomeState extends State<MusicPlayerHome> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration? _duration;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  String? _currentSongPath;
  String? _lastMusicFolder;  // 添加这一行
  Song? get currentSong => _currentSongPath != null ? Song.fromPath(_currentSongPath!) : null;
  bool _isPlaylistVisible = true;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadLastMusicFolder();  // 添加这一行
    _audioPlayer = AudioPlayer();

    _audioPlayer.playerStateStream.listen((state) {
      debugPrint(
          'Player state changed: ${state.processingState} - playing: ${state.playing}');
      setState(() {
        _isPlaying = state.playing;
      });

      // 处理播放完成的情况
      if (state.processingState == ProcessingState.completed) {
        final musicState =
            Provider.of<MusicPlayerState>(context, listen: false);
        switch (musicState.playMode) {
          case PlayMode.sequential:
            _playNext();
            break;
          case PlayMode.repeat:
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
            break;
          case PlayMode.shuffle:
            _playRandomSong();
            break;
        }
      }
    });

    _audioPlayer.playbackEventStream.listen((event) {
      debugPrint('Playback event: ${event.processingState}');
    }, onError: (error) {
      debugPrint('Error in playback stream: $error');
    });

    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.volumeStream.listen((volume) {
      setState(() {
        _volume = volume;
      });
      Provider.of<MusicPlayerState>(context, listen: false).setVolume(volume);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<MusicPlayerState>(context, listen: false);
      state.addListener(() {
        final newSong = state.currentSong;
        debugPrint('Current song changed: $newSong');
        if (newSong != null && newSong != _currentSongPath) {
          debugPrint('Attempting to play: $newSong');
          _currentSongPath = newSong;
          try {
            _audioPlayer.stop().then((_) {
              return _audioPlayer.setFilePath(newSong);
            }).then((_) {
              debugPrint('File loaded successfully');
              return _audioPlayer.play();
            }).then((_) {
              debugPrint('Play command sent successfully');
            }).catchError((error) {
              debugPrint('Error playing file: $error');
              _currentSongPath = null;
            });
          } catch (e) {
            debugPrint('Error setting up audio player: $e');
            _currentSongPath = null;
          }
        }
      });
    });

    // 设置初始音量
    _audioPlayer.setVolume(_volume);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // 先检查权限状态
      Map<Permission, PermissionStatus> currentStatuses = {
        Permission.storage: await Permission.storage.status,
        Permission.audio: await Permission.audio.status,
        Permission.bluetooth: await Permission.bluetooth.status,
        Permission.mediaLibrary: await Permission.mediaLibrary.status,
        Permission.accessMediaLocation: await Permission.accessMediaLocation.status,
        Permission.manageExternalStorage: await Permission.manageExternalStorage.status,
        Permission.videos: await Permission.videos.status,
        Permission.photos: await Permission.photos.status,
      };

      // 打印当前权限状态
      currentStatuses.forEach((permission, status) {
        debugPrint('当前权限状态 - ${_getPermissionText(permission)}: $status');
      });

      // 只请求未授权的权限
      List<Permission> permissionsToRequest = currentStatuses.entries
          .where((entry) => !entry.value.isGranted)
          .map((entry) => entry.key)
          .toList();

      if (permissionsToRequest.isNotEmpty) {
        debugPrint('请求以下权限: ${permissionsToRequest.map((p) => _getPermissionText(p)).join(', ')}');
        Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();
        
        bool allGranted = true;
        String deniedPermissions = '';

        // 重新检查所有权限状态
        currentStatuses.forEach((permission, status) async {
          PermissionStatus currentStatus = await permission.status;
          debugPrint('权限请求后状态 - ${_getPermissionText(permission)}: $currentStatus');
          if (!currentStatus.isGranted && 
              currentStatus != PermissionStatus.limited &&
              currentStatus != PermissionStatus.provisional) {
            allGranted = false;
            deniedPermissions += '\n- ${_getPermissionText(permission)}';
          }
        });

        if (!allGranted && mounted) {
          debugPrint('以下权限未授予: $deniedPermissions');
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('需要权限'),
              content: Text('以下权限被拒绝，应用可能无法正常工作：$deniedPermissions\n\n请在系统设置中手动开启这些权限。'),
              actions: [
                TextButton(
                  onPressed: () async {
                    await openAppSettings();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('打开设置'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
              ],
            ),
          );
        }
      } else {
        debugPrint('所有必要权限已授予');
      }
    }
  }

  String _getPermissionText(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return '存储';
      case Permission.audio:
        return '音频';
      case Permission.bluetooth:
        return '蓝牙';
      case Permission.mediaLibrary:
        return '媒体库';
      case Permission.accessMediaLocation:
        return '媒体位置';
      case Permission.manageExternalStorage:
        return '管理外部存储';
      case Permission.videos:
        return '视频';
      case Permission.photos:
        return '照片';
      default:
        return '未知';
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _pickAndPlayMusic() async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('选择导入方式'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'files');
              },
              child: const Text('选择音乐文件'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'folder');
              },
              child: const Text('选择文件夹'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    List<String> paths = [];
    if (result == 'files') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        paths = result.paths.whereType<String>().toList();
      }
    } else {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(initialDirectory: _lastMusicFolder); // 添加这一行

      if (selectedDirectory != null) {
        paths = await _getAudioFilesFromDirectory(selectedDirectory);
        _saveLastMusicFolder(selectedDirectory); // 添加这一行
      }
    }

    if (paths.isNotEmpty) {
      final state = Provider.of<MusicPlayerState>(context, listen: false);
      state.setPlaylist(paths);
      state.setCurrentSong(paths[0]);
      await _audioPlayer.setFilePath(paths[0]);
      await _audioPlayer.play();
    }
  }

  Future<List<String>> _getAudioFilesFromDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    List<String> audioFiles = [];

    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          String path = entity.path.toLowerCase();
          if (path.endsWith('.mp3') ||
              path.endsWith('.wav') ||
              path.endsWith('.flac') ||
              path.endsWith('.m4a') ||
              path.endsWith('.aac') ||
              path.endsWith('.ogg')) {
            audioFiles.add(entity.path);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory: $e');
    }

    return audioFiles;
  }

  Future<void> _playNext() async {
    final state = Provider.of<MusicPlayerState>(context, listen: false);
    String? nextSong = state.getNextSong();
    if (nextSong != null) {
      await _audioPlayer.setFilePath(nextSong);
      await _audioPlayer.play();
    }
  }

  Future<void> _playPrevious() async {
    final state = Provider.of<MusicPlayerState>(context, listen: false);
    String? previousSong = state.getPreviousSong();
    if (previousSong != null) {
      await _audioPlayer.setFilePath(previousSong);
      await _audioPlayer.play();
    }
  }

  Future<void> _playRandomSong() async {
    final state = Provider.of<MusicPlayerState>(context, listen: false);
    String? randomSong = state.getRandomSong();
    if (randomSong != null) {
      await _audioPlayer.setFilePath(randomSong);
      await _audioPlayer.play();
    }
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequential:
        return Icons.arrow_forward;
      case PlayMode.repeat:
        return Icons.repeat_one;
      case PlayMode.shuffle:
        return Icons.shuffle;
    }
  }

  void _changePlayMode() {
    final state = Provider.of<MusicPlayerState>(context, listen: false);
    switch (state.playMode) {
      case PlayMode.sequential:
        state.setPlayMode(PlayMode.repeat);
        break;
      case PlayMode.repeat:
        state.setPlayMode(PlayMode.shuffle);
        break;
      case PlayMode.shuffle:
        state.setPlayMode(PlayMode.sequential);
        break;
    }
  }

  Future<void> _loadLastMusicFolder() async {
    final prefs = await SharedPreferences.getInstance();
    _lastMusicFolder = prefs.getString('lastMusicFolder');
  }

  Future<void> _saveLastMusicFolder(String folderPath) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('lastMusicFolder', folderPath);
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF121212),
        title: const Text('音乐播放器', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndPlayMusic,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Expanded(
                  child: Consumer<MusicPlayerState>(
                    builder: (context, state, child) {
                      return state.currentSong != null
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    margin: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(20.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20.0),
                                      child: AudioVisualizer(
                                        isPlaying: _isPlaying,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 30,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: LyricsView(
                                      currentSong: state.currentSong,
                                      position: _position,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: Text(
                                '暂无播放内容',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isPortrait ? 16 : 24,
                    vertical: isPortrait ? 16 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      ProgressBar(
                        progress: _position,
                        total: _duration ?? Duration.zero,
                        onSeek: (duration) {
                          _audioPlayer.seek(duration);
                        },
                        barHeight: isPortrait ? 4 : 6,
                        baseBarColor: const Color(0xFF2A2A2A),
                        progressBarColor: const Color(0xFF1DB954),
                        thumbColor: const Color(0xFF1DB954),
                        timeLabelLocation: TimeLabelLocation.sides,
                        timeLabelTextStyle: const TextStyle(color: Colors.white54),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Consumer<MusicPlayerState>(
                            builder: (context, state, child) {
                              return IconButton(
                                icon: Icon(_getPlayModeIcon(state.playMode)),
                                color: Colors.white,
                                onPressed: _changePlayMode,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            color: Colors.white,
                            onPressed: _playPrevious,
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1DB954).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            iconSize: 56,
                            color: Colors.white,
                            onPressed: () {
                              if (_isPlaying) {
                                _audioPlayer.pause();
                              } else {
                                _audioPlayer.play();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            color: Colors.white,
                            onPressed: _playNext,
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up),
                            color: Colors.white,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[900],
                                  title: const Text(
                                    '音量控制',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Consumer<MusicPlayerState>(
                                    builder: (context, state, child) {
                                      return Container(
                                        height: 50,
                                        child: Column(
                                          children: [
                                            Slider(
                                              value: state.volume,
                                              min: 0.0,
                                              max: 1.0,
                                              onChanged: (value) {
                                                state.setVolume(value);
                                                _audioPlayer.setVolume(value);
                                              },
                                              activeColor: Colors.blue,
                                              inactiveColor: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        '确定',
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isPortrait)
            Container(
              width: 300,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Colors.grey[900]!,
                    width: 1,
                  ),
                ),
              ),
              child: const PlaylistView(),
            ),
        ],
      ),
    );
  }
}
