import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/offline_sync_service.dart';
import '../../services/pdf_cache_service.dart';

/// My Library (point #5): every downloaded test lives here, viewable and
/// attemptable fully offline. Grid/list toggle; premium items whose access
/// has lapsed are shown greyed-out with only stats visible (point #23).
class MyLibraryScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onToggleDark;
  const MyLibraryScreen({super.key, required this.darkMode, required this.onToggleDark});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await OfflineSyncService.syncLibraryManifest();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openOffline(Map<String, dynamic> item) async {
    if (item['still_accessible'] == false) return;
    if (item['pdf_url'] == null) return;
    await PdfCacheService.getOrDownloadPaper(paperId: item['paper_id'], pdfUrl: item['pdf_url']);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cached "${item['title']}" for offline viewing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.darkMode ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = widget.darkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            activeLabel: 'My Library',
            onSelect: (_) {},
            darkMode: widget.darkMode,
            onToggleDark: widget.onToggleDark,
            onLogout: () {},
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Library', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Row(children: [
                        IconButton(
                          icon: const Icon(Icons.grid_view),
                          color: _gridView ? AppColors.purple : secondaryText,
                          onPressed: () => setState(() => _gridView = true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.view_list),
                          color: !_gridView ? AppColors.purple : secondaryText,
                          onPressed: () => setState(() => _gridView = false),
                        ),
                      ]),
                    ],
                  ),
                  Text('Downloaded tests — view, attempt, and check offline',
                      style: TextStyle(color: secondaryText, fontSize: 13)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                        : _items.isEmpty
                            ? Center(child: Text('No downloaded tests yet.', style: TextStyle(color: secondaryText)))
                            : (_gridView ? _buildGrid(borderColor, secondaryText) : _buildList(borderColor, secondaryText)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(Color borderColor, Color secondaryText) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.3,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) => _libraryCard(_items[i], borderColor, secondaryText),
    );
  }

  Widget _buildList(Color borderColor, Color secondaryText) {
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => SizedBox(height: 90, child: _libraryCard(_items[i], borderColor, secondaryText)),
    );
  }

  Widget _libraryCard(Map<String, dynamic> item, Color borderColor, Color secondaryText) {
    final accessible = item['still_accessible'] != false;
    return Opacity(
      opacity: accessible ? 1.0 : 0.5,
      child: InkWell(
        onTap: accessible ? () => _openOffline(item) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.picture_as_pdf, color: AppColors.purple, size: 22),
              const SizedBox(height: 8),
              Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              const Spacer(),
              Text(
                accessible ? item['paper_type'] ?? '' : 'Premium access expired',
                style: TextStyle(fontSize: 10.5, color: accessible ? secondaryText : Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}