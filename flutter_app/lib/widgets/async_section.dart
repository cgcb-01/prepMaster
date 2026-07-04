import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Generic "fetch -> loading / error+retry / data" wrapper used by every
/// screen instead of each one hand-rolling its own try/catch-with-fake-data
/// fallback. On failure this shows a real error + Retry button — it never
/// silently swaps in sample data, so a broken API call is visible instead
/// of being masked.
class AsyncSection<T> extends StatefulWidget {
  final Future<T> Function() fetcher;
  final Widget Function(BuildContext context, T data, VoidCallback refresh) builder;

  const AsyncSection({super.key, required this.fetcher, required this.builder});

  @override
  State<AsyncSection<T>> createState() => AsyncSectionState<T>();
}

class AsyncSectionState<T> extends State<AsyncSection<T>> with AutomaticKeepAliveClientMixin {
  late Future<T> _future;

  @override
  bool get wantKeepAlive => true; // survives IndexedStack tab switches

  @override
  void initState() {
    super.initState();
    _future = widget.fetcher();
  }

  void refresh() => setState(() => _future = widget.fetcher());

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.purple)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 32, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('Could not load this — ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: refresh, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        return widget.builder(context, snapshot.data as T, refresh);
      },
    );
  }
}
