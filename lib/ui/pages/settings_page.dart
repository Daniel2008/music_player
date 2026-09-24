import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import '../../providers/api_settings_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/gd_music_api.dart';
import '../../services/connectivity_service.dart';
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
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                children: [
                  // API 设置
                  _buildSection(
                    context,
                    title: 'API 配置',
                    icon: Icons.hub_outlined,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'API 地址',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _apiUrlController,
                                    decoration: InputDecoration(
                                      hintText:
                                          ApiSettingsProvider.defaultApiBaseUrl,
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildTestButton(apiSettings),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () async {
                                    await apiSettings.setApiBaseUrl(
                                      _apiUrlController.text,
                                    );
                                    if (context.mounted) {
                                      // 同步到共享 API 客户端
                                      final api = context
                                          .read<GdMusicApiClient>();
                                      api.updateBaseUrl(apiSettings.apiBaseUrl);
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
                                    child: Icon(Icons.save_outlined, size: 20),
                                  ),
                                ),
                              ],
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
                                          ? Colors.green
                                          : scheme.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _connectionTestResult! ? '连接成功' : '连接失败',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _connectionTestResult!
                                            ? Colors.green
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
                  const SizedBox(height: 12),

                  // 音乐源设置
                  MusicSourceSettingsSection(apiSettings: apiSettings),
                  const SizedBox(height: 12),

                  // 音质设置
                  AudioQualitySettingsSection(
                    apiSettings: apiSettings,
                    downloadProvider: downloadProvider,
                    playerProvider: playerProvider,
                  ),
                  const SizedBox(height: 12),

                  // 下载设置
                  DownloadSettingsSection(downloadProvider: downloadProvider),
                  const SizedBox(height: 12),

                  // 歌词设置
                  LyricSettingsSection(
                    apiSettings: apiSettings,
                    playerProvider: playerProvider,
                  ),
                  const SizedBox(height: 12),

                  // 外观设置
                  AppearanceSettingsSection(theme: theme),
                  const SizedBox(height: 12),

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
                  const SizedBox(height: 12),

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
                          'v1.0.0',
                          style: TextStyle(color: scheme.outline),
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
}
