import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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
  bool _fetching = false;
  String? _error;
  VideoMeta? _meta;
  OutFormat _format = OutFormat.mp3;
  int _mp3Kbps = 192;
  int _mp4H = 720;
  double? _progress;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
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
      // Binary wiring lands in Task 5; for now surface a clear message
      // if no yt-dlp binary path is configured.
      throw Exception(
        'Preview fetch needs the yt-dlp binary (Task 5). URL looks valid.',
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YTGet')),
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
            onPressed: _meta == null ? null : () {},
            icon: const Icon(Icons.download),
            label: const Text('Download (Task 5)'),
          ),
          if (_log.isNotEmpty)
            ExpansionTile(
              title: const Text('Log'),
              children: _log.map((l) => Text(l)).toList(),
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
