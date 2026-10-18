import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../core/history_store.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({required this.history, required this.onBrowse, super.key});

  final HistoryController history;
  final VoidCallback onBrowse;

  Future<void> _openPath(BuildContext context, String path) async {
    final r = await OpenFilex.open(path);
    if (r.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.message.startsWith('No app found')
                ? 'No app can open this file type.'
                : r.message,
          ),
        ),
      );
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear download history?'),
        content: const Text(
          'This removes the list shown here. Downloaded files stay on disk — '
          'delete them from your file manager if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await history.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('History cleared')));
    }
  }

  String _dateLabel(Map<String, dynamic> e) {
    final d = DateTime.tryParse((e['date'] ?? '').toString());
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    String two(int v) => v.toString().padLeft(2, '0');
    if (day == today) return '${two(d.hour)}:${two(d.minute)}';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final entries = history.entries;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: entries.isEmpty
          ? _EmptyState(onBrowse: onBrowse, key: const ValueKey('empty'))
          : ListView.separated(
              key: const ValueKey('list'),
              padding: const EdgeInsets.all(16),
              itemCount: entries.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          '${entries.length} item${entries.length == 1 ? '' : 's'}',
                          style: TextStyle(color: theme.hintColor),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _confirmClearAll(context),
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label: const Text('Clear all'),
                        ),
                      ],
                    ),
                  );
                }
                final e = entries[index - 1];
                final isAudio = e['format'] == 'mp3';
                final date = _dateLabel(e);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAudio
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.tertiaryContainer,
                    child: Icon(
                      isAudio ? Icons.headphones : Icons.videocam,
                      color: isAudio
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  title: Text(
                    (e['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$date • ${e['format']?.toString().toUpperCase()} • ${(e['path'] ?? '').toString()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.hintColor),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        tooltip: 'Open',
                        onPressed: () =>
                            _openPath(context, (e['path'] ?? '').toString()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'Share',
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            files: [XFile((e['path'] ?? '').toString())],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove from history',
                        onPressed: () async {
                          await history.removeWhere(
                            (x) => x['path'] == e['path'],
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Removed from history (file stays on disk)',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBrowse, super.key});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No downloads yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Files you download will show up here.\n'
            'They stay available even after closing the app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: onBrowse,
            icon: const Icon(Icons.ondemand_video),
            label: const Text('Start a download'),
          ),
        ],
      ),
    );
  }
}
