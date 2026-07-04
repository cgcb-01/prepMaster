import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../services/pdf_cache_service.dart';
import '../../widgets/async_section.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});
  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  bool _gridView = true;

  Future<List<Map>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/sync/library/manifest/');
    final manifest = List<Map<String, dynamic>>.from(resp.data);
    await PdfCacheService.reconcileWithManifest(manifest);
    return PdfCacheService.listLibraryItems();
  }

  Future<void> _delete(int paperId, VoidCallback refresh) async {
    await PdfCacheService.deletePaper(paperId);
    refresh();
  }

  void _openPaper(Map item, {required bool solution}) {
    final path = solution ? item['solution_path'] : item['question_path'];
    if (path == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => _OfflinePdfViewerScreen(title: item['title'], filePath: path)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Library', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Row(children: [
                IconButton(icon: Icon(Icons.grid_view, color: _gridView ? AppColors.purple : secondaryText), onPressed: () => setState(() => _gridView = true)),
                IconButton(icon: Icon(Icons.view_list, color: !_gridView ? AppColors.purple : secondaryText), onPressed: () => setState(() => _gridView = false)),
              ]),
            ],
          ),
          Text('Downloaded tests, viewable offline', style: TextStyle(color: secondaryText, fontSize: 12.5)),
          const SizedBox(height: 16),
          Expanded(
            child: AsyncSection<List<Map>>(
              fetcher: _fetch,
              builder: (context, items, refresh) => items.isEmpty
                  ? Center(child: Text('Nothing downloaded yet.', style: TextStyle(color: secondaryText)))
                  : (_gridView
                      ? GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.85),
                          itemCount: items.length,
                          itemBuilder: (context, i) => _card(items[i], borderColor, refresh),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            final accessible = item['still_accessible'] != false;
                            return Container(
                              decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.picture_as_pdf, color: AppColors.purple),
                                title: Text(item['title'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                subtitle: Text(accessible ? 'Question paper + solution' : 'Premium expired — solution removed', style: TextStyle(fontSize: 11, color: accessible ? secondaryText : Colors.orange)),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'view') _openPaper(item, solution: false);
                                    if (v == 'solution') _openPaper(item, solution: true);
                                    if (v == 'delete') _delete(item['paper_id'], refresh);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'view', child: Text('View Question Paper')),
                                    if (accessible) const PopupMenuItem(value: 'solution', child: Text('View Solution')),
                                    const PopupMenuItem(value: 'delete', child: Text('Remove from Library')),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map item, Color borderColor, VoidCallback refresh) {
    final accessible = item['still_accessible'] != false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.picture_as_pdf, color: AppColors.purple, size: 28),
          const SizedBox(height: 8),
          Text(item['title'] ?? '', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          if (!accessible) const Text('Premium expired', style: TextStyle(fontSize: 9.5, color: Colors.orange)),
          Row(children: [
            Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)), onPressed: () => _openPaper(item, solution: false), child: const Text('Open', style: TextStyle(fontSize: 11)))),
            IconButton(iconSize: 16, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(item['paper_id'], refresh)),
          ]),
        ],
      ),
    );
  }
}

class _OfflinePdfViewerScreen extends StatelessWidget {
  final String title;
  final String filePath;
  const _OfflinePdfViewerScreen({required this.title, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)), body: SfPdfViewer.file(File(filePath)));
  }
}
