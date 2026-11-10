import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/download_provider.dart';
import '../theme/app_design.dart';
import 'app_surfaces.dart';

void showDownloadManagerSheet(BuildContext context) {
  final downloadProvider = context.read<DownloadProvider>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: downloadProvider,
      builder: (context, _) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.download_rounded,
                      size: 20,
                      color: context.scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '下载管理',
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (downloadProvider.pendingTasks.isNotEmpty)
                      TextButton.icon(
                        onPressed: downloadProvider.startPendingDownloads,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('开始等待任务'),
                      ),
                    if (downloadProvider.failedTasks.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => downloadProvider.retryAllFailed(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重试全部'),
                      ),
                    if (downloadProvider.completedTasks.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => downloadProvider.clearCompleted(),
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: const Text('清除已完成'),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.visual.border),
              Expanded(
                child: downloadProvider.allTasks.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.download_done_rounded,
                        title: '暂无下载任务',
                        description: '在搜索结果中下载的歌曲会显示在这里。',
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: downloadProvider.allTasks.length,
                        itemBuilder: (context, index) {
                          return _DownloadTaskTile(
                            task: downloadProvider.allTasks[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final visual = context.visual;

    IconData statusIcon;
    Color statusColor;
    switch (task.status) {
      case DownloadStatus.pending:
        statusIcon = Icons.schedule_rounded;
        statusColor = scheme.onSurfaceVariant;
        break;
      case DownloadStatus.downloading:
        statusIcon = Icons.downloading_rounded;
        statusColor = scheme.primary;
        break;
      case DownloadStatus.completed:
        statusIcon = Icons.check_circle_rounded;
        statusColor = visual.success;
        break;
      case DownloadStatus.failed:
        statusIcon = Icons.error_rounded;
        statusColor = scheme.error;
        break;
      case DownloadStatus.cancelled:
        statusIcon = Icons.cancel_rounded;
        statusColor = scheme.onSurfaceVariant;
        break;
    }

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.14),
          borderRadius: AppRadius.smAll,
        ),
        child: Icon(statusIcon, color: statusColor, size: 19),
      ),
      title: Text(
        task.track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyles.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.track.artistText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (task.status == DownloadStatus.downloading)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.xsAll,
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 4,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    task.progressDisplay,
                    style: context.textStyles.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          if (task.status == DownloadStatus.failed && task.error != null)
            Text(
              task.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.labelSmall?.copyWith(
                color: scheme.error,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.status == DownloadStatus.failed ||
              task.status == DownloadStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () =>
                  context.read<DownloadProvider>().retryDownload(task.id),
              tooltip: '重试',
            ),
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.pending)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => context.read<DownloadProvider>().cancelDownload(
                task.track.source,
                task.track.id,
              ),
              tooltip: '取消',
            ),
          if (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () =>
                  context.read<DownloadProvider>().removeTask(task.id),
              tooltip: '移除',
            ),
        ],
      ),
    );
  }
}
