import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/user_profile.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  const AuthState({required this.status, this.profile});

  bool get isAdmin => profile?.isStaff ?? false;

  AuthState copyWith({AuthStatus? status, UserProfile? profile}) =>
      AuthState(status: status ?? this.status, profile: profile ?? this.profile);
}

/// Central auth/session state. Screens read `authProvider` instead of each
/// re-implementing their own login/profile-fetch logic. Wrap the app in a
/// ProviderScope and consume via `ref.watch(authProvider)` to migrate the
/// existing setState-based screens over incrementally.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.unknown));

  Future<void> login(String username, String password) async {
    await ApiClient.login(username, password);
    await fetchProfile();
  }

  Future<void> register(Map<String, dynamic> payload) async {
    await ApiClient.register(payload);
    await fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final resp = await ApiClient.dio.get('/api/users/me/');
      state = AuthState(status: AuthStatus.authenticated, profile: UserProfile.fromJson(resp.data));
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> logout() async {
    await ApiClient.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
