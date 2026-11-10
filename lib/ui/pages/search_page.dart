import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/api_settings_provider.dart';
import '../../providers/search_provider.dart';
import '../theme/app_design.dart';
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: AppPanel(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final field = TextField(
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
                      ),
                      onSubmitted: (_) => _search(searchProvider),
                    );
                    final button = FilledButton.icon(
                      onPressed: searchProvider.isSearching
                          ? null
                          : () => _search(searchProvider),
                      icon: searchProvider.isSearching
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.scheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: const Text('搜索'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(
                          92,
                          AppSpacing.controlHeight + 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                      ),
                    );

                    // 窄窗口时按钮换到下一行，避免输入框被压得太窄。
                    if (constraints.maxWidth < 420) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          const SizedBox(height: AppSpacing.md),
                          button,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: AppSpacing.md),
                        button,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm + 2,
                  runSpacing: AppSpacing.sm,
                  children: [
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: searchProvider.searchError != null
                ? _buildErrorState(searchProvider)
                : searchProvider.isSearching
                ? const CompactSearchLoadingList()
                : searchProvider.searchResults.isEmpty
                ? _buildEmptyState()
                : CompactSearchResultList(
                    items: searchProvider.searchResults,
                    quality: currentQuality,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.manage_search_rounded,
      title: '开始搜索',
      description: '输入歌名、歌手或专辑名称，结果会按当前音乐源显示。',
    );
  }

  Widget _buildErrorState(SearchProvider searchProvider) {
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
    final scheme = context.scheme;
    final visual = context.visual;
    final match = items.where((e) => e.$1 == value).firstOrNull;
    final selectedLabel = match?.$2 ?? value;

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: '选择$label',
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
                  const SizedBox(width: AppSpacing.sm + 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(item.$2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: visual.accentSurface,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label  $selectedLabel',
              style: context.textStyles.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
