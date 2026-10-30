import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/device_logger_service.dart';

class LiveLogsScreen extends StatefulWidget {
  const LiveLogsScreen({super.key});

  @override
  State<LiveLogsScreen> createState() => _LiveLogsScreenState();
}

class _LiveLogsScreenState extends State<LiveLogsScreen> {
  static const String _defaultPasscode = '303134';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _passcodeController = TextEditingController();
  bool _isPaused = false;
  bool _isUnlocked = false;
  bool _passcodeIncorrect = false;
  List<String> _pausedEntries = const [];

  @override
  void dispose() {
    _searchController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isOwnerUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live app logs')),
        body: const Center(
          child: Text('Only the business owner can view app logs.'),
        ),
      );
    }

    if (!_isUnlocked) {
      return _buildUnlockScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live app logs'),
        actions: [
          IconButton(
            tooltip: _isPaused ? 'Resume live logs' : 'Pause live logs',
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              setState(() {
                if (!_isPaused) {
                  _pausedEntries = DeviceLoggerService.entries.value;
                }
                _isPaused = !_isPaused;
              });
            },
          ),
          IconButton(
            tooltip: 'Copy visible logs',
            icon: const Icon(Icons.copy),
            onPressed: _copyVisibleLogs,
          ),
          IconButton(
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Filter logs',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear filter',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _isPaused ? Icons.pause_circle_outline : Icons.circle,
                  size: 14,
                  color: _isPaused ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(_isPaused ? 'Paused' : 'Live'),
                const Spacer(),
                const Text('Recent logs are kept in memory only'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: DeviceLoggerService.entries,
              builder: (context, entries, _) {
                final source = _isPaused ? _pausedEntries : entries;
                final filter = _searchController.text.trim().toLowerCase();
                final visibleEntries = source
                    .where((entry) => entry.toLowerCase().contains(filter))
                    .toList()
                    .reversed
                    .toList();

                if (visibleEntries.isEmpty) {
                  return Center(
                    child: Text(
                      filter.isEmpty
                          ? 'No logs yet. App messages and errors will appear here.'
                          : 'No logs match your filter.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: visibleEntries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => SelectableText(
                    visibleEntries[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live app logs')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Enter the log viewer passcode',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passcodeController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_passcodeIncorrect) {
                      setState(() => _passcodeIncorrect = false);
                    }
                  },
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: 'Passcode',
                    errorText: _passcodeIncorrect ? 'Incorrect passcode' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _unlock,
                    child: const Text('Unlock logs'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _unlock() {
    if (_passcodeController.text != _defaultPasscode) {
      setState(() => _passcodeIncorrect = true);
      return;
    }

    setState(() {
      _isUnlocked = true;
      _passcodeIncorrect = false;
      _passcodeController.clear();
    });
  }

  List<String> get _visibleEntries {
    final source =
        _isPaused ? _pausedEntries : DeviceLoggerService.entries.value;
    final filter = _searchController.text.trim().toLowerCase();
    return source
        .where((entry) => entry.toLowerCase().contains(filter))
        .toList();
  }

  Future<void> _copyVisibleLogs() async {
    await Clipboard.setData(ClipboardData(text: _visibleEntries.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visible logs copied')),
    );
  }

  void _clearLogs() {
    DeviceLoggerService.clear();
    setState(() {
      _pausedEntries = const [];
    });
  }
}
