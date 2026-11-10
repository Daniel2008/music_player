import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import '../../providers/api_settings_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/visualizer_settings_provider.dart';
import '../../services/gd_music_api.dart';
import '../../services/connectivity_service.dart';
import '../theme/app_design.dart';
import '../widgets/appearance_settings_section.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/playback_settings_sections.dart';
import '../widgets/settings_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiUrlController = TextEditingController();
  bool _isTestingConnection = false;
  bool? _connectionTestResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final apiSettings = context.read<ApiSettingsProvider>();
      _apiUrlController.text = apiSettings.apiBaseUrl;
    });
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final apiSettings = context.watch<ApiSettingsProvider>();
    final downloadProvider = context.watch<DownloadProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    final visualizerSettings = context.watch<VisualizerSettingsProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const AppPageHeader(
          title: '设置',
          eyebrow: '偏好设置',
          icon: Icons.tune_rounded,
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.settingsMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.xxl + AppSpacing.xs,
                ),
                children: [
                  // API 设置
                  _buildSection(
                    context,
                    title: 'API 配置',
                    icon: Icons.hub_outlined,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'API 地址',
                              style: context.textStyles.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final field = TextField(
                                  controller: _apiUrlController,
                                  decoration: const InputDecoration(
                                    hintText:
                                        ApiSettingsProvider.defaultApiBaseUrl,
                                    isDense: true,
                                  ),
                                  style: context.textStyles.bodyMedium,
                                );
                                final actions = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTestButton(apiSettings),
                                    const SizedBox(width: AppSpacing.sm),
                                    FilledButton.tonal(
                                      onPressed: () async {
                                        await apiSettings.setApiBaseUrl(
                                          _apiUrlController.text,
                                        );
                                        if (context.mounted) {
                                          // 同步到共享 API 客户端
                                          final api = context
                                              .read<GdMusicApiClient>();
                                          api.updateBaseUrl(
                                            apiSettings.apiBaseUrl,
                                          );
                                          context
                                              .read<ConnectivityService>()
                                              .updateApiHost(api.baseUri);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('API 地址已保存'),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Tooltip(
                                        message: '保存 API 地址',
                                        child: Icon(
                                          Icons.save_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                );

                                if (constraints.maxWidth < 520) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      field,
                                      const SizedBox(height: AppSpacing.md),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: actions,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: field),
                                    const SizedBox(width: AppSpacing.sm),
                                    actions,
                                  ],
                                );
                              },
                            ),
                            if (_connectionTestResult != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      _connectionTestResult!
                                          ? Icons.check_circle
                                          : Icons.error,
                                      size: 16,
                                      color: _connectionTestResult!
                                          ? context.visual.success
                                          : scheme.error,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      _connectionTestResult! ? '连接成功' : '连接失败',
                                      style: context.textStyles.labelMedium
                                          ?.copyWith(
                                            color: _connectionTestResult!
                                                ? context.visual.success
                                                : scheme.error,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '请求超时',
                        subtitle: '${apiSettings.requestTimeout} 秒',
                        trailing: SizedBox(
                          width: 150,
                          child: Slider(
                            value: apiSettings.requestTimeout.toDouble(),
                            min: 5,
                            max: 30,
                            divisions: 25,
                            label: '${apiSettings.requestTimeout}秒',
                            onChanged: (value) {
                              final seconds = value.round();
                              apiSettings.setRequestTimeout(seconds);
                              // 同步到共享 API 客户端
                              context
                                  .read<GdMusicApiClient>()
                                  .updateTimeoutSeconds(seconds);
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '显示不稳定音乐源',
                        subtitle: '部分源可能无法使用',
                        trailing: Switch(
                          value: apiSettings.showUnstableSources,
                          onChanged: (value) {
                            apiSettings.setShowUnstableSources(value);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '重置为默认设置',
                        subtitle: '恢复所有 API 相关设置',
                        trailing: TextButton(
                          onPressed: () =>
                              _confirmResetApiSettings(context, apiSettings),
                          child: const Text('重置'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gutter),

                  // 音乐源设置
                  MusicSourceSettingsSection(apiSettings: apiSettings),
                  const SizedBox(height: AppSpacing.gutter),

                  // 音质设置
                  AudioQualitySettingsSection(
                    apiSettings: apiSettings,
                    downloadProvider: downloadProvider,
                    playerProvider: playerProvider,
                  ),
                  const SizedBox(height: AppSpacing.gutter),

                  _buildVisualizerSettings(context, visualizerSettings),
                  const SizedBox(height: AppSpacing.gutter),

                  // 下载设置
                  DownloadSettingsSection(downloadProvider: downloadProvider),
                  const SizedBox(height: AppSpacing.gutter),

                  // 歌词设置
                  LyricSettingsSection(
                    apiSettings: apiSettings,
                    playerProvider: playerProvider,
                  ),
                  const SizedBox(height: AppSpacing.gutter),

                  // 外观设置
                  AppearanceSettingsSection(theme: theme),
                  const SizedBox(height: AppSpacing.gutter),

                  // 快捷键
                  _buildSection(
                    context,
                    title: '快捷键',
                    icon: Icons.keyboard_outlined,
                    children: [
                      _buildTile(
                        context,
                        title: '播放/暂停',
                        trailing: _buildShortcut('Ctrl+Alt+P'),
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '上一首',
                        trailing: _buildShortcut('Ctrl+Alt+←'),
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '下一首',
                        trailing: _buildShortcut('Ctrl+Alt+→'),
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '全屏频谱',
                        trailing: _buildShortcut('F11'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gutter),

                  // 关于
                  _buildSection(
                    context,
                    title: '关于',
                    icon: Icons.info_outline,
                    children: [
                      _buildTile(
                        context,
                        title: '版本',
                        trailing: Text(
                          'v1.2.0+2',
                          style: context.textStyles.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '音乐 API',
                        subtitle: 'GD 音乐台 (music.gdstudio.xyz)',
                        trailing: Icon(
                          Icons.open_in_new_rounded,
                          color: scheme.outline,
                          size: 20,
                        ),
                        onTap: () async {
                          final url = Uri.parse(
                            'https://music-api.gdstudio.xyz',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      _buildTile(
                        context,
                        title: '免责声明',
                        subtitle: '本应用仅供学习交流使用',
                        onTap: () => _showDisclaimer(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestButton(ApiSettingsProvider apiSettings) {
    return FilledButton.tonal(
      onPressed: _isTestingConnection
          ? null
          : () async {
              setState(() {
                _isTestingConnection = true;
                _connectionTestResult = null;
              });

              // 临时更新 URL 进行测试
              final originalUrl = apiSettings.apiBaseUrl;
              await apiSettings.setApiBaseUrl(_apiUrlController.text);

              final result = await apiSettings.testConnection();

              // 如果测试失败，恢复原来的 URL
              if (!result) {
                await apiSettings.setApiBaseUrl(originalUrl);
              }

              setState(() {
                _isTestingConnection = false;
                _connectionTestResult = result;
              });
            },
      child: _isTestingConnection
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('测试'),
    );
  }

  void _confirmResetApiSettings(
    BuildContext context,
    ApiSettingsProvider apiSettings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置 API 设置'),
        content: const Text('确定要将所有 API 相关设置恢复为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await apiSettings.resetToDefaults();
              if (!context.mounted) return;
              final api = context.read<GdMusicApiClient>();
              final downloads = context.read<DownloadProvider>();
              final connectivity = context.read<ConnectivityService>();
              api.updateBaseUrl(apiSettings.apiBaseUrl);
              api.updateTimeoutSeconds(apiSettings.requestTimeout);
              downloads.defaultQuality = apiSettings.downloadQuality.brValue;
              connectivity.updateApiHost(api.baseUri);
              _apiUrlController.text = apiSettings.apiBaseUrl;
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已重置为默认设置')));
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('免责声明'),
        content: const SingleChildScrollView(
          child: Text(
            '本应用仅供学习和研究使用，不得用于商业用途。\n\n'
            '本应用使用的音乐资源来自网络，版权归原作者所有。如有侵权，请联系我们删除。\n\n'
            '使用本应用即表示您同意以上条款。',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return SettingsSection(title: title, icon: icon, children: children);
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildShortcut(String keys) {
    return ShortcutBadge(keys: keys);
  }

  Widget _buildVisualizerSettings(
    BuildContext context,
    VisualizerSettingsProvider settings,
  ) {
    return _buildSection(
      context,
      title: '频谱可视化',
      icon: Icons.graphic_eq_rounded,
      children: [
        _buildTile(
          context,
          title: '灵敏度',
          subtitle: '${settings.sensitivity.toStringAsFixed(1)}x',
          trailing: SizedBox(
            width: 170,
            child: Slider(
              value: settings.sensitivity,
              min: 0.4,
              max: 2.5,
              divisions: 21,
              label: '${settings.sensitivity.toStringAsFixed(1)}x',
              onChanged: settings.setSensitivity,
            ),
          ),
        ),
        const Divider(height: 1),
        _buildTile(
          context,
          title: '平滑度',
          subtitle: settings.smoothing < 0.35 ? '快速响应' : '柔和过渡',
          trailing: SizedBox(
            width: 170,
            child: Slider(
              value: settings.smoothing,
              min: 0,
              max: 1,
              divisions: 10,
              label: settings.smoothing.toStringAsFixed(1),
              onChanged: settings.setSmoothing,
            ),
          ),
        ),
        const Divider(height: 1),
        _buildTile(
          context,
          title: '发光强度',
          subtitle: '${(settings.glowStrength * 100).round()}%',
          trailing: SizedBox(
            width: 170,
            child: Slider(
              value: settings.glowStrength,
              min: 0,
              max: 1.8,
              divisions: 18,
              label: '${(settings.glowStrength * 100).round()}%',
              onChanged: settings.setGlowStrength,
            ),
          ),
        ),
        const Divider(height: 1),
        _buildTile(
          context,
          title: '背景透明度',
          subtitle: '${(settings.backgroundOpacity * 100).round()}%',
          trailing: SizedBox(
            width: 170,
            child: Slider(
              value: settings.backgroundOpacity,
              min: 0,
              max: 0.45,
              divisions: 9,
              label: '${(settings.backgroundOpacity * 100).round()}%',
              onChanged: settings.setBackgroundOpacity,
            ),
          ),
        ),
        const Divider(height: 1),
        _buildTile(
          context,
          title: '刷新率上限',
          subtitle: '${settings.maxFps} FPS',
          trailing: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 15, label: Text('省电')),
              ButtonSegment(value: 30, label: Text('均衡')),
              ButtonSegment(value: 60, label: Text('流畅')),
            ],
            selected: {
              settings.maxFps <= 15
                  ? 15
                  : settings.maxFps >= 60
                  ? 60
                  : 30,
            },
            onSelectionChanged: (value) => settings.setMaxFps(value.first),
          ),
        ),
      ],
    );
  }
}
