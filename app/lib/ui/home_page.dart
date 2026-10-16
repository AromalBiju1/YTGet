import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';

import '../core/binary_manager.dart';
import '../core/download_args.dart';
import '../core/history_store.dart';
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
  bool _fetching = false;
  bool _downloading = false;
  String? _error;
  VideoMeta? _meta;
  OutFormat _format = OutFormat.mp3;
  int _mp3Kbps = 192;
  int _mp4H = 720;
  double? _progress;
  final List<String> _log = [];
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _reloadHistory();
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
      final bin = await BinaryManager.ensureExecutable();
      final meta = await YtDlp(bin).fetchInfo(raw);
      setState(() => _meta = meta);
    } catch (e) {
      setState(
        () => _error = e.toString().replaceFirst('Exception: ', '').split('\n').first,
      );
    } finally {
      setState(() => _fetching = false);
    }
  }

  Future<Directory> _outDir() async {
    final dl = await getDownloadsDirectory();
    final base = dl ?? await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/YTGet');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _download() async {
    final raw = _urlCtrl.text.trim();
    if (_meta == null) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _log.clear();
      _error = null;
    });
    try {
      final bin = await BinaryManager.ensureExecutable();
      final dir = await _outDir();
      final safeTitle = _meta!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = _format == OutFormat.mp3 ? 'mp3' : 'mp4';
      final outTpl = '${dir.path}/$safeTitle.%(ext)s';
      final args = _format == OutFormat.mp3
          ? buildMp3Args(raw, _mp3Kbps, outTpl)
          : buildMp4Args(raw, _mp4H, outTpl);
      await for (final p in YtDlp(bin).download(
        args,
        onLog: (l) => setState(() {
          _log.add(l);
          if (_log.length > 200) _log.removeAt(0);
        }),
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
      setState(
        () => _error = e.toString().replaceFirst('Exception: ', '').split('\n').first,
      );
    } finally {
      setState(() {
        _downloading = false;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YTGet'),
        actions: [
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
            onPressed: _fetching ? null : _fetch,
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
          FilledButton.icon(
            onPressed: (_meta == null || _downloading) ? null : _download,
            icon: const Icon(Icons.download),
            label: Text(_downloading ? 'Downloading…' : 'Download'),
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
                    onPressed: () => OpenFilex.open((e['path'] ?? '').toString()),
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
  String _ver = '…';
  @override
  void initState() {
    super.initState();
    BinaryManager.ensureExecutable()
        .then((b) => BinaryManager.version(b))
        .then((v) => setState(() => _ver = v))
        .catchError((e) => setState(() => _ver = 'missing — run tool/fetch_ytdlp.sh'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('yt-dlp version'), subtitle: Text(_ver)),
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
