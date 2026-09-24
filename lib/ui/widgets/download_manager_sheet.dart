import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/download_provider.dart';

void showDownloadManagerSheet(BuildContext context) {
  final downloadProvider = context.read<DownloadProvider>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('下载管理', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (downloadProvider.failedTasks.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => downloadProvider.retryAllFailed(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重试全部'),
                  ),
                if (downloadProvider.completedTasks.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => downloadProvider.clearCompleted(),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('清除已完成'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: downloadProvider.allTasks.isEmpty
                ? const Center(child: Text('暂无下载任务'))
                : ListView.builder(
                    controller: scrollController,
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
  );
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    IconData statusIcon;
    Color statusColor;
    switch (task.status) {
      case DownloadStatus.pending:
        statusIcon = Icons.schedule;
        statusColor = scheme.outline;
        break;
      case DownloadStatus.downloading:
        statusIcon = Icons.downloading;
        statusColor = scheme.primary;
        break;
      case DownloadStatus.completed:
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case DownloadStatus.failed:
        statusIcon = Icons.error;
        statusColor = scheme.error;
        break;
      case DownloadStatus.cancelled:
        statusIcon = Icons.cancel;
        statusColor = scheme.outline;
        break;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(
        task.track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.track.artistText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          if (task.status == DownloadStatus.downloading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: task.progress,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.progressDisplay,
                    style: TextStyle(fontSize: 10, color: scheme.outline),
                  ),
                ],
              ),
            ),
          if (task.status == DownloadStatus.failed && task.error != null)
            Text(
              task.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: scheme.error),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.status == DownloadStatus.failed ||
              task.status == DownloadStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () =>
                  context.read<DownloadProvider>().retryDownload(task.id),
              tooltip: '重试',
            ),
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.pending)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => context.read<DownloadProvider>().cancelDownload(
                task.track.source,
                task.track.id,
              ),
              tooltip: '取消',
            ),
          if (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () =>
                  context.read<DownloadProvider>().removeTask(task.id),
              tooltip: '移除',
            ),
        ],
      ),
    );
  }
}
