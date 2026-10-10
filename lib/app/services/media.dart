import 'package:flutter/material.dart';

import 'config.dart';

/// Listening audio and content images are kept in Cloudflare R2, not in the
/// app, under `ielts_app_phone_version/`:
///
/// | App path (in the content JSON)   | R2 key (after the prefix)         |
/// |----------------------------------|-----------------------------------|
/// | assets/audio/listening/<f>       | listening/audio/<f>               |
/// | assets/listening/maps/<f>        | listening/maps/<f>                |
/// | assets/writing/task1/<f>         | writing/task1-images/<f>          |
/// | assets/writing/tests/<f>         | writing/task1-images/<f>          |
/// | assets/writing/guide/<f>         | writing/guide-images/<f>          |
/// | assets/diagrams/app/<f>          | reading/images/<f>                |
///
/// Students' speaking recordings go to `speaking/<user id>/<attempt id>/`
/// (written by the API server). The content JSON keeps the asset paths;
/// [url] turns them into links. Anything else stays a bundled asset.
class Media {
  Media._();

  static const Map<String, String> _folders = <String, String>{
    'assets/audio/listening/': 'listening/audio/',
    'assets/listening/maps/': 'listening/maps/',
    'assets/writing/task1/': 'writing/task1-images/',
    'assets/writing/tests/': 'writing/task1-images/',
    'assets/writing/guide/': 'writing/guide-images/',
    'assets/diagrams/app/': 'reading/images/',
  };

  /// R2 key (below the app prefix) for a media asset path, or null when the
  /// path stays bundled in the app.
  static String? keyOf(String asset) {
    for (final e in _folders.entries) {
      if (asset.startsWith(e.key)) return '${e.value}${asset.substring(e.key.length)}';
    }
    return null;
  }

  /// Download link for [asset], or null when it is bundled (or no media
  /// server is configured).
  static String? url(String asset) {
    final key = keyOf(asset);
    final base = AppConfig.mediaBaseUrl;
    if (key == null || base.isEmpty) return null;
    return '$base/${key.split('/').map(Uri.encodeComponent).join('/')}';
  }
}

/// [Image.asset] for bundled images, [Image.network] for media kept in R2.
/// A failed load shows [errorBuilder] (or nothing) instead of throwing.
class MediaImage extends StatelessWidget {
  const MediaImage(
    this.path, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  });

  final String path;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final onError = errorBuilder ?? (context, error, stack) => SizedBox(width: width, height: height ?? 40);
    final url = Media.url(path);
    if (url == null) {
      return Image.asset(
        path,
        fit: fit,
        width: width,
        height: height,
        semanticLabel: semanticLabel,
        errorBuilder: onError,
      );
    }
    return Image.network(
      url,
      // Web: the R2 bucket sends no CORS headers, so Flutter's own image
      // fetch is blocked there. Fall back to a plain <img> element, which
      // needs no CORS. Phones are not affected.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      fit: fit,
      width: width,
      height: height,
      semanticLabel: semanticLabel,
      errorBuilder: onError,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : SizedBox(
              width: width,
              height: height ?? 120,
              child: const Center(
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
    );
  }
}
