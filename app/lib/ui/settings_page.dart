import 'package:flutter/material.dart';

import '../core/native_ytdlp.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
