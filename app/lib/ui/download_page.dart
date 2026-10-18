import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/app_notifier.dart';
import '../core/download_args.dart';
import '../core/history_store.dart';
import '../core/native_ytdlp.dart';
import '../core/save_location.dart';
import '../core/youtube_url.dart';
import '../core/ytdlp_service.dart';

enum OutFormat { mp3, mp4 }

class DownloadPage extends StatefulWidget {
  const DownloadPage({
    required this.native,
    required this.history,
    required this.engineReady,
    required this.engineError,
    required this.notifier,
    required this.onSwitchToHistory,
    super.key,
  });

  final NativeYtDlp native;
  final HistoryController history;
  final bool engineReady;
  final String? engineError;
  final AppNotifier notifier;
  final VoidCallback onSwitchToHistory;

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _urlCtrl = TextEditingController();
  bool _fetching = false;
  bool _downloading = false;
  bool _cancelled = false;
  bool _done = false;
  String? _error;
  VideoMeta? _meta;
  OutFormat _format = OutFormat.mp3;
  int _mp3Kbps = 192;
  int _mp4H = 720;
  double? _progress;
  String? _processId;
  SaveMode _saveMode = SaveMode.publicDownloads;
  String? _customSavePath;

  @override
  void initState() {
    super.initState();
    _loadSaveSettings();
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _urlCtrl.text = files.first.path;
        _fetch();
      }
    }).catchError((Object _) {});
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty && mounted) {
          setState(() => _urlCtrl.text = files.first.path);
          _fetch();
        }
      },
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadSaveSettings() async {
    final mode = await SaveLocation.load();
    final path = await SaveLocation.loadCustomPath();
    if (!mounted) return;
    setState(() {
      _saveMode = mode;
      _customSavePath = path;
    });
  }

  String get _saveFolderSubtitle {
    switch (_saveMode) {
      case SaveMode.publicDownloads:
        return 'Downloads/YTGet (public)';
      case SaveMode.appPrivate:
        return 'App storage/YTGet (private)';
      case SaveMode.custom:
        return _customSavePath ?? 'Choose a folder…';
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _urlCtrl.text = d!.text!.trim());
  }

  Future<void> _fetch() async {
    final raw = _urlCtrl.text.trim();
    if (!YoutubeUrl.isSupportedUrl(raw)) {
      setState(() => _error = 'That does not look like a YouTube link.');
      return;
    }
    setState(() {
      _fetching = true;
      _error = null;
      _meta = null;
      _done = false;
    });
    try {
      final meta = await widget.native
          .getInfo(raw)
          .timeout(const Duration(seconds: 45));
      setState(() => _meta = meta);
    } on TimeoutException {
      setState(
        () => _error =
            'Fetching timed out — check your connection and try again.',
      );
    } on PlatformException catch (e) {
      setState(() => _error = (e.message ?? e.code).split('\n').first);
    } catch (e) {
      setState(() => _error = '$e'.split('\n').first);
    } finally {
      setState(() => _fetching = false);
    }
  }

  /// Resolve the target output directory for the user's chosen save mode.
  Future<Directory> _outDir() async {
    switch (_saveMode) {
      case SaveMode.appPrivate:
        return _appPrivateOutDir();
      case SaveMode.custom:
        final p = _customSavePath;
        if (p != null) {
          try {
            final dir = Directory(p);
            await dir.create(recursive: true);
            return dir;
          } catch (_) {
            _snack('Custom folder unavailable — using app storage.');
          }
        }
        return _appPrivateOutDir();
      case SaveMode.publicDownloads:
        if (await _ensureStorageAccess()) {
          final dir = Directory('/storage/emulated/0/Download/YTGet');
          await dir.create(recursive: true);
          await _migrateLegacyFiles(dir);
          return dir;
        }
        return _appPrivateOutDir();
    }
  }

  Future<Directory> _appPrivateOutDir() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/YTGet');
    await dir.create(recursive: true);
    return dir;
  }

  Future<bool> _ensureStorageAccess() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final res = await Permission.manageExternalStorage.request();
    if (res.isGranted) return true;
    _snack(
      'Allow "All files access" for folders outside app storage, '
      'or files stay app-private.',
    );
    return false;
  }

  Future<void> _showSaveSheet() async {
    final res = await showModalBottomSheet<SaveMode?>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: RadioGroup<SaveMode>(
          groupValue: _saveMode,
          onChanged: (v) => Navigator.pop(sheetCtx, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SaveMode>(
                title: const Text('Downloads/YTGet'),
                subtitle: const Text(
                  'Public folder — visible in any file manager. Recommended.',
                ),
                value: SaveMode.publicDownloads,
              ),
              RadioListTile<SaveMode>(
                title: const Text('App storage'),
                subtitle: const Text(
                  'App-private — no "all files" permission needed.',
                ),
                value: SaveMode.appPrivate,
              ),
              ListTile(
                onTap: () async {
                  final p = await _pickCustomFolder();
                  if (p != null && sheetCtx.mounted) {
                    Navigator.pop(sheetCtx, SaveMode.custom);
                  }
                },
                title: const Text('Custom folder…'),
                subtitle: Text(
                  _customSavePath ?? 'Browse your device for a folder',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.folder_open, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
    if (res == null) return;
    if (res == SaveMode.custom && _customSavePath == null) return;
    await SaveLocation.save(res);
    if (!mounted) return;
    setState(() => _saveMode = res);
    _snack('Files will be saved to: $_saveFolderSubtitle');
  }

  Future<String?> _pickCustomFolder() async {
    if (!await _ensureStorageAccess()) return null;
    final p = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder',
    );
    if (p == null) return null;
    if (p == '/' || !p.startsWith('/')) {
      _snack('That location is not usable — pick a folder on device storage.');
      return null;
    }
    await SaveLocation.saveCustomPath(p);
    if (mounted) setState(() => _customSavePath = p);
    return p;
  }

  /// Moves files downloaded before the public-folder switch into Download/YTGet.
  Future<void> _migrateLegacyFiles(Directory target) async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext == null) return;
      final legacy = Directory('${ext.path}/YTGet');
      if (!await legacy.exists()) return;
      await for (final e in legacy.list()) {
        if (e is File) {
          final dest = File('${target.path}/${e.uri.pathSegments.last}');
          if (!await dest.exists()) await e.rename(dest.path);
        }
      }
    } catch (_) {}
  }

  /// yt-dlp output titles come from YouTube metadata — cap the length and
  /// strip separators/characters that break filenames.
  String _safeTitle(String title) {
    var t = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    t = t.replaceAll(RegExp(r'[\x00-\x1F]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 120) t = t.substring(0, 120).trim();
    if (t.startsWith('.')) t = '_${t.substring(1)}';
    if (t.isEmpty) t = 'ytget-download';
    return t;
  }

  String _durFmt(int s) {
    if (s <= 0) return '—';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
  }

  /// yt-dlp reaches 100% before the ffmpeg merge/conversion step; while that
  /// runs the UI shows an indeterminate bar instead of sticking at 100%.
  bool get _reached100 => _progress != null && _progress! >= 0.999;

  /// Warns when the same video was already downloaded in the same format.
  /// Returns whether to continue.
  Future<bool> _confirmDuplicate() async {
    final raw = _urlCtrl.text.trim();
    final ext = _format == OutFormat.mp3 ? 'mp3' : 'mp4';
    Map<String, dynamic>? existing;
    for (final e in widget.history.entries) {
      if ((e['url'] ?? '').toString() == raw &&
          (e['format'] ?? '').toString() == ext) {
        existing = e;
        break;
      }
    }
    if (existing == null) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Already downloaded'),
        content: Text(
          '"${existing!['title']}" is already in your history '
          '(${existing['format']} — saved at ${existing['date']}).\n\n'
          'Download it again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'open'),
            child: const Text('Open file'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'again'),
            child: const Text('Download again'),
          ),
        ],
      ),
    );
    switch (choice) {
      case 'open':
        OpenFilex.open((existing['path'] ?? '').toString());
        return false;
      case 'again':
        return true;
      default:
        return false;
    }
  }

  Future<void> _download() async {
    final raw = _urlCtrl.text.trim();
    if (_meta == null) return;
    if (!await _confirmDuplicate()) return;
    setState(() {
      _downloading = true;
      _cancelled = false;
      _done = false;
      _progress = 0;
      _error = null;
      _processId = DateTime.now().millisecondsSinceEpoch.toString();
    });
    try {
      final dir = await _outDir();
      final safeTitle = _safeTitle(_meta!.title);
      final ext = _format == OutFormat.mp3 ? 'mp3' : 'mp4';
      final outTpl = '${dir.path}/$safeTitle.%(ext)s';
      final fullArgs = _format == OutFormat.mp3
          ? buildMp3Args(raw, _mp3Kbps, outTpl)
          : buildMp4Args(raw, _mp4H, outTpl);
      // Last element is the URL (passed separately to the native request).
      final options = fullArgs.sublist(0, fullArgs.length - 1);
      await for (final p in widget.native.download(
        processId: _processId!,
        url: raw,
        options: options,
      )) {
        setState(() => _progress = p);
      }
      final file = File('${dir.path}/$safeTitle.$ext');
      await widget.history.add({
        'title': _meta!.title,
        'path': file.path,
        'format': ext,
        'url': raw,
      });
      await widget.notifier.downloadDone(_meta!.title);
      _snack('Saved to ${file.path}');
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (!_cancelled) {
        setState(() => _error = '$e'.split('\n').first);
      }
    } finally {
      setState(() {
        _downloading = false;
        _progress = null;
        _processId = null;
      });
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelled = true);
    if (_processId != null) {
      await widget.native.cancel(_processId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            labelText: 'YouTube link',
            hintText: 'https://youtu.be/...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: _paste,
            ),
          ),
          keyboardType: TextInputType.url,
          onSubmitted: (v) => _fetch(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: (_fetching || !widget.engineReady) ? null : _fetch,
          icon: const Icon(Icons.search),
          label: Text(_fetching ? 'Fetching…' : 'Preview'),
        ),
        if (widget.engineError != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.engineError!,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _meta != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  key: ValueKey('meta-${_meta!.title}'),
                  child: _previewCard(),
                )
              : const SizedBox(height: 0, key: ValueKey('no-meta')),
        ),
        const SizedBox(height: 16),
        _formatPicker(theme),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.folder_open),
            title: const Text('Save to'),
            subtitle: Text(
              _saveFolderSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.swap_horiz, size: 20),
            onTap: _showSaveSheet,
          ),
        ),
        const SizedBox(height: 16),
        if (_downloading)
          TweenAnimationBuilder<double>(
            tween: Tween(end: _progress),
            duration: const Duration(milliseconds: 150),
            builder: (context, v, _) => Column(
              children: [
                LinearProgressIndicator(
                  value: _reached100 ? null : v,
                  minHeight: 6,
                ),
                const SizedBox(height: 4),
                Text(
                  _reached100
                      ? 'Processing… (merging / converting)'
                      : '${(v * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _reached100 ? theme.hintColor : null,
                  ),
                ),
              ],
            ),
          )
        else if (_done)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Column(
              children: [
                LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: Colors.green,
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Downloaded',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: (_meta == null || _downloading || !widget.engineReady)
                    ? null
                    : _download,
                icon: Icon(
                  _done && !_downloading ? Icons.check_circle : Icons.download,
                ),
                label: Text(
                  _downloading
                      ? (_reached100 ? 'Processing…' : 'Downloading…')
                      : (_done ? 'Downloaded' : 'Download'),
                ),
              ),
            ),
            if (_downloading) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.stop),
                label: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _previewCard() {
    final m = _meta!;
    return Card(
      child: ListTile(
        leading: m.thumb.isEmpty
            ? const Icon(Icons.video_library)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: m.thumb,
                  width: 72,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(m.title),
        subtitle: Text('${m.author} • ${_durFmt(m.durSec)}'),
      ),
    );
  }

  Widget _formatPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<OutFormat>(
          segments: const [
            ButtonSegment(value: OutFormat.mp3, label: Text('MP3')),
            ButtonSegment(value: OutFormat.mp4, label: Text('MP4')),
          ],
          selected: {_format},
          onSelectionChanged: (s) => setState(() => _format = s.first),
        ),
        const SizedBox(height: 8),
        if (_format == OutFormat.mp3)
          DropdownButtonFormField<int>(
            initialValue: _mp3Kbps,
            decoration: const InputDecoration(labelText: 'Quality'),
            items: const [
              DropdownMenuItem(value: 128, child: Text('128 kbps')),
              DropdownMenuItem(value: 192, child: Text('192 kbps')),
              DropdownMenuItem(value: 320, child: Text('320 kbps')),
            ],
            onChanged: (v) => setState(() => _mp3Kbps = v ?? 192),
          )
        else
          DropdownButtonFormField<int>(
            initialValue: _mp4H,
            decoration: const InputDecoration(labelText: 'Quality'),
            items: const [
              DropdownMenuItem(value: 720, child: Text('720p')),
              DropdownMenuItem(value: 1080, child: Text('1080p')),
            ],
            onChanged: (v) => setState(() => _mp4H = v ?? 720),
          ),
      ],
    );
  }
}
