class AppConfig {
  AppConfig._();

  /// Set with --dart-define=API_BASE_URL=https://api.example.com
  /// Do not place private provider keys here.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static bool get hasApiBaseUrl => apiBaseUrl.startsWith('https://');
}
