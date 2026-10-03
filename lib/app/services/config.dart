/// Build-time configuration.
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://ielts-ai-api.<you>.workers.dev \
///             --dart-define=APP_KEY=<shared key>
/// ```
///
/// Without `API_BASE_URL` the app runs fully offline with its demo scorer.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String appKey = String.fromEnvironment('APP_KEY');

  /// True when an API backend is configured.
  static bool get hasApi => apiBaseUrl.isNotEmpty;

  /// Where the listening audio and the reading / writing / map images live
  /// (Cloudflare R2, see [Media]). `MEDIA_BASE_URL` points straight at a
  /// public bucket domain (…/ielts_app_phone_version); otherwise the API
  /// server's `/v1/media` redirects to short-lived signed R2 links.
  static const String _mediaBaseUrl = String.fromEnvironment('MEDIA_BASE_URL');

  static String get mediaBaseUrl {
    String trim(String s) => s.endsWith('/') ? s.substring(0, s.length - 1) : s;
    if (_mediaBaseUrl.isNotEmpty) return trim(_mediaBaseUrl);
    return hasApi ? '${trim(apiBaseUrl)}/v1/media' : '';
  }
}
