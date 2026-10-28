import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/config/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal HTTPS client. A backend is not connected until a real endpoint
/// has been configured and successfully tested.
class ApiClient {
  ApiClient({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;

  Future<Object?> getJson(String path) async {
    if (!AppConfig.hasApiBaseUrl) {
      throw const ApiException('لم يتم إعداد عنوان الخادم السحابي بعد.');
    }
    final base = Uri.tryParse(AppConfig.apiBaseUrl);
    if (base == null || base.scheme != 'https') {
      throw const ApiException('عنوان الخادم غير صالح أو لا يستخدم HTTPS.');
    }
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    final uri = base.resolve(relativePath);
    try {
      final request = await _client.getUrl(uri).timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('تعذّر تحميل البيانات (HTTP ${response.statusCode}).');
      }
      try {
        return jsonDecode(body);
      } on FormatException {
        throw const ApiException('استجابة الخادم ليست بصيغة JSON صحيحة.');
      }
    } on TimeoutException {
      throw const ApiException('استغرق الاتصال وقتًا طويلًا. حاول مرة أخرى.');
    } on SocketException {
      throw const ApiException('تعذّر الوصول إلى الخادم. تحقق من الإنترنت.');
    } on HttpException {
      throw const ApiException('حدث خطأ أثناء الاتصال بالخادم.');
    }
  }

  void close() => _client.close(force: true);
}
