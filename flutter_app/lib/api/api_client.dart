import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Central Dio instance. Attaches the JWT access token to every request and
/// transparently refreshes it on a 401 using the stored refresh token.
class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  static final Dio dio = Dio(BaseOptions(baseUrl: baseUrl))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final req = error.requestOptions;
            final token = await _storage.read(key: 'access_token');
            req.headers['Authorization'] = 'Bearer $token';
            final clone = await dio.fetch(req);
            return handler.resolve(clone);
          }
        }
        handler.next(error);
      },
    ));

  static Future<bool> _tryRefresh() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return false;
    try {
      final resp = await Dio(BaseOptions(baseUrl: baseUrl))
          .post('/api/auth/token/refresh/', data: {'refresh': refresh});
      await _storage.write(key: 'access_token', value: resp.data['access']);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> login(String username, String password) async {
    final resp = await dio.post('/api/auth/token/', data: {
      'username': username,
      'password': password,
    });
    await _storage.write(key: 'access_token', value: resp.data['access']);
    await _storage.write(key: 'refresh_token', value: resp.data['refresh']);
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}