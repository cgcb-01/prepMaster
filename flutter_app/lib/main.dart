import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'app_shell.dart';
import 'screens/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/offline_sync_service.dart';
import 'services/pdf_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Both local-storage services must be initialized (Hive boxes opened)
  // before ANY screen touches them — this was the actual cause of "My
  // Library" errors: the old main.dart never called these, so
  // Hive.box(...) threw the first time a screen tried to read from it.
  await OfflineSyncService.init();
  await PdfCacheService.init();
  runApp(const ProviderScope(child: PrepMasterApp()));
}

class PrepMasterApp extends ConsumerStatefulWidget {
  const PrepMasterApp({super.key});
  @override
  ConsumerState<PrepMasterApp> createState() => _PrepMasterAppState();
}

class _PrepMasterAppState extends ConsumerState<PrepMasterApp> {
  @override
  void initState() {
    super.initState();
    // Silent auto-login: if a JWT is already in secure storage from a
    // previous session, this populates authProvider without showing the
    // login screen again. If there's no token or it's expired, fetchProfile
    // fails quietly and AuthGate below falls through to LoginScreen.
    Future.microtask(() => ref.read(authProvider.notifier).fetchProfile());
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    return MaterialApp(
      title: 'PrepMaster',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

/// Shows a spinner while the silent auto-login check runs, then routes to
/// LoginScreen or the real AppShell based on real auth state — not a guess.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.purple)));
      case AuthStatus.authenticated:
        return const AppShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
