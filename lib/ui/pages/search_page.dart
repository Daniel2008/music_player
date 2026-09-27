import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/api_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/search_results_compact_view.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  String? _source;
  String? _quality;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final apiSettings = context.read<ApiSettingsProvider>();
      setState(() {
        _source = apiSettings.defaultSource;
        _quality = apiSettings.playQuality.brValue;
      });
    });
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  List<(String, String)> _getAvailableSources(ApiSettingsProvider apiSettings) {
    return apiSettings.availableSources.map((s) => (s.id, s.name)).toList();
  }

  List<(String, String)> _getQualityOptions() {
    return AudioQuality.values
        .map((q) => (q.brValue, '${q.description} ${q.label}'))
        .toList();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(SearchProvider searchProvider) {
    final q = _controller.text.trim();
    if (q.isNotEmpty) {
      final apiSettings = context.read<ApiSettingsProvider>();
      final source = _source ?? apiSettings.defaultSource;
      searchProvider.searchOnline(q, source: source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    final apiSettings = context.watch<ApiSettingsProvider>();
    final scheme = Theme.of(context).colorScheme;

    // 确保有默认值
    final currentSource = _source ?? apiSettings.defaultSource;
    final currentQuality = _quality ?? apiSettings.playQuality.brValue;

    return Column(
      children: [
        const AppPageHeader(
          title: '在线音乐',
          eyebrow: '发现',
          icon: Icons.search_rounded,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: AppPanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '搜索歌曲、歌手、专辑...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _hasText
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: '清空搜索',
                                  onPressed: () {
                                    _controller.clear();
                                    searchProvider.clearSearch();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _search(searchProvider),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: searchProvider.isSearching
                          ? null
                          : () => _search(searchProvider),
                      icon: searchProvider.isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: const Text('搜索'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(92, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    // 音乐源选择
                    _buildChipSelector(
                      context: context,
                      label: '音乐源',
                      value: currentSource,
                      items: _getAvailableSources(apiSettings),
                      onChanged: (v) {
                        setState(() => _source = v);
                        if (_controller.text.trim().isNotEmpty) {
                          _search(searchProvider);
                        }
                      },
                    ),
                    // 音质选择
                    _buildChipSelector(
                      context: context,
                      label: '音质',
                      value: currentQuality,
                      items: _getQualityOptions(),
                      onChanged: (v) => setState(() => _quality = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: searchProvider.searchError != null
                ? _buildErrorState(scheme, searchProvider)
                : searchProvider.isSearching
                ? const CompactSearchLoadingList()
                : searchProvider.searchResults.isEmpty
                ? _buildEmptyState(scheme)
                : CompactSearchResultList(
                    items: searchProvider.searchResults,
                    quality: currentQuality,
                  ),
          ),
        ),
      ],
    );
  }

  /// 空状态
  Widget _buildEmptyState(ColorScheme scheme) {
    return const AppEmptyState(
      icon: Icons.manage_search_rounded,
      title: '开始搜索',
      description: '输入歌名、歌手或专辑名称，结果会按当前音乐源显示。',
    );
  }

  /// 错误状态
  Widget _buildErrorState(ColorScheme scheme, SearchProvider searchProvider) {
    return AppEmptyState(
      icon: Icons.cloud_off_rounded,
      title: '搜索失败',
      description: searchProvider.searchError,
      action: FilledButton.tonalIcon(
        onPressed: () => _search(searchProvider),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('重试'),
      ),
    );
  }

  Widget _buildChipSelector({
    required BuildContext context,
    required String label,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
    final selectedLabel = items.firstWhere((e) => e.$1 == value).$2;

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem(
              value: item.$1,
              child: Row(
                children: [
                  Icon(
                    item.$1 == value
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: item.$1 == value ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Text(item.$2),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: visual.panelMuted.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label  $selectedLabel',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
