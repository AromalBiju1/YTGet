import 'package:flutter/material.dart';

import '../core/app_notifier.dart';
import '../core/history_store.dart';
import '../core/native_ytdlp.dart';
import 'download_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  bool _engineReady = false;
  String? _engineError;
  late final HistoryController _history;
  final _native = NativeYtDlp();
  final _notifier = AppNotifier();

  @override
  void initState() {
    super.initState();
    _history = HistoryController(HistoryStore());
    _history.refresh();
    _native.init().then((_) {
      if (mounted) setState(() => _engineReady = true);
    }).catchError((Object e) {
      if (mounted) setState(() => _engineError = 'Engine init failed: $e');
    });
    _notifier.init();
  }

  void _goToTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/logo.png',
                  height: 26,
                  width: 26,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.video_library, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('YTGet'),
          ],
        ),
        actions: [
          if (!_engineReady && _engineError == null)
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
            tooltip: 'Settings',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      // IndexedStack keeps both pages (and any running downloads) alive while
      // the user browses the other tab.
      body: IndexedStack(
        index: _tab,
        children: [
          DownloadPage(
            native: _native,
            history: _history,
            engineReady: _engineReady,
            engineError: _engineError,
            notifier: _notifier,
            onSwitchToHistory: () => _goToTab(1),
          ),
          HistoryPage(history: _history, onBrowse: () => _goToTab(0)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.ondemand_video_outlined),
            selectedIcon: Icon(Icons.ondemand_video),
            label: 'Download',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
