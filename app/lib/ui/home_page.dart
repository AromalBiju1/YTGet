import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';

import '../core/download_args.dart';
import '../core/history_store.dart';
import '../core/native_ytdlp.dart';
import '../core/youtube_url.dart';
import '../core/ytdlp_service.dart';

enum OutFormat { mp3, mp4 }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlCtrl = TextEditingController();
  final _history = HistoryStore();
  final _native = NativeYtDlp();
  bool _fetching = false;
  bool _downloading = false;
  bool _engineReady = false;
  String? _error;
  VideoMeta? _meta;
  OutFormat _format = OutFormat.mp3;
  int _mp3Kbps = 192;
  int _mp4H = 720;
  double? _progress;
  String? _processId;
  final List<String> _log = [];
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _reloadHistory();
    _native.init().then((_) {
      if (mounted) setState(() => _engineReady = true);
    }).catchError((Object e) {
      if (mounted) {
        setState(() => _error = 'Engine init failed: $e');
      }
    });
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _urlCtrl.text = files.first.path;
        _fetch();
      }
    });
    ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty && mounted) {
        setState(() => _urlCtrl.text = files.first.path);
        _fetch();
      }
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    _entries = await _history.list();
    if (mounted) setState(() {});
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
    });
    try {
      final meta = await _native.getInfo(raw);
      setState(() => _meta = meta);
    } on PlatformException catch (e) {
      setState(() => _error = (e.message ?? e.code).split('\n').first);
    } catch (e) {
      setState(() => _error = '$e'.split('\n').first);
    } finally {
      setState(() => _fetching = false);
    }
  }

  /// Public Download/YTGet folder. Needs MANAGE_EXTERNAL_STORAGE
  /// ("Allow all files") on Android 11+. Falls back to the app-private
  /// dir if access isn't granted.
  Future<Directory> _outDir() async {
    if (await _ensureStorageAccess()) {
      final dir = Directory('/storage/emulated/0/Download/YTGet');
      await dir.create(recursive: true);
      await _migrateLegacyFiles(dir);
      return dir;
    }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow "All files access" for the public Downloads folder, '
            'or files stay app-private.',
          ),
        ),
      );
    }
    return false;
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

  Future<void> _download() async {
    final raw = _urlCtrl.text.trim();
    if (_meta == null) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _log.clear();
      _error = null;
      _processId = DateTime.now().millisecondsSinceEpoch.toString();
    });
    try {
      final dir = await _outDir();
      final safeTitle = _meta!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = _format == OutFormat.mp3 ? 'mp3' : 'mp4';
      final outTpl = '${dir.path}/$safeTitle.%(ext)s';
      final fullArgs = _format == OutFormat.mp3
          ? buildMp3Args(raw, _mp3Kbps, outTpl)
          : buildMp4Args(raw, _mp4H, outTpl);
      // Last element is the URL (passed separately to the native request).
      final options = fullArgs.sublist(0, fullArgs.length - 1);
      await for (final p in _native.download(
        processId: _processId!,
        url: raw,
        options: options,
      )) {
        setState(() => _progress = p);
      }
      final file = File('${dir.path}/$safeTitle.$ext');
      await _history.add({
        'title': _meta!.title,
        'path': file.path,
        'format': ext,
        'url': raw,
      });
      await _reloadHistory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
      }
    } catch (e) {
      setState(() => _error = '$e'.split('\n').first);
    } finally {
      setState(() {
        _downloading = false;
        _progress = null;
        _processId = null;
      });
    }
  }

  Future<void> _cancel() async {
    if (_processId != null) {
      await _native.cancel(_processId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YTGet'),
        actions: [
          if (!_engineReady)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _SettingsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
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
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (_fetching || !_engineReady) ? null : _fetch,
            icon: const Icon(Icons.search),
            label: Text(_fetching ? 'Fetching…' : 'Preview'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          if (_meta != null) _previewCard(),
          const SizedBox(height: 16),
          _formatPicker(),
          const SizedBox(height: 16),
          if (_progress != null)
            Column(
              children: [
                LinearProgressIndicator(value: _progress),
                Text('${((_progress ?? 0) * 100).toStringAsFixed(1)}%'),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_meta == null || _downloading || !_engineReady)
                      ? null
                      : _download,
                  icon: const Icon(Icons.download),
                  label: Text(_downloading ? 'Downloading…' : 'Download'),
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
          if (_log.isNotEmpty)
            ExpansionTile(
              title: const Text('Log'),
              children: _log.reversed.take(30).map((l) => Text(l)).toList(),
            ),
          const Divider(),
          const Text('History'),
          ..._entries.map(
            (e) => ListTile(
              title: Text((e['title'] ?? '').toString()),
              subtitle: Text((e['path'] ?? '').toString()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () =>
                        OpenFilex.open((e['path'] ?? '').toString()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.shareXFiles([
                      XFile((e['path'] ?? '').toString()),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final m = _meta!;
    return Card(
      child: ListTile(
        leading: m.thumb.isEmpty
            ? const Icon(Icons.video_library)
            : CachedNetworkImage(
                imageUrl: m.thumb,
                width: 72,
                height: 48,
                fit: BoxFit.cover,
              ),
        title: Text(m.title),
        subtitle: Text('${m.author} • ${m.durSec}s'),
      ),
    );
  }

  Widget _formatPicker() {
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

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _native = NativeYtDlp();
  String _ver = '…';
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _native.version().then((v) {
      if (mounted) setState(() => _ver = v);
    }).catchError((Object e) {
      if (mounted) setState(() => _ver = 'error: $e');
    });
  }

  Future<void> _update() async {
    setState(() => _updating = true);
    try {
      final s = await _native.update();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update: $s')));
        setState(() => _ver = 'updated ($s) — reopen to refresh');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('yt-dlp version'),
            subtitle: Text(_ver),
            trailing: _updating
                ? const CircularProgressIndicator()
                : TextButton(onPressed: _update, child: const Text('Update')),
          ),
          const Text(
            'Personal use only. Only download your own videos, Creative Commons, '
            'or content you have permission for. YouTube ToS applies. '
            'Sideload only — never for the Play Store.',
          ),
        ],
      ),
    );
  }
}
