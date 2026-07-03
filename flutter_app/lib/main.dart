import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/offline_sync_service.dart';
import 'services/pdf_cache_service.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineSyncService.init();
  await PdfCacheService.init();
  runApp(const PrepMasterApp());
}

class PrepMasterApp extends StatefulWidget {
  const PrepMasterApp({super.key});
  @override
  State<PrepMasterApp> createState() => _PrepMasterAppState();
}

class _PrepMasterAppState extends State<PrepMasterApp> {
  bool _darkMode = true;

  void _toggleDark(bool v) => setState(() => _darkMode = v);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrepMaster',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(darkMode: _darkMode, onToggleDark: _toggleDark),
    );
  }
}
