import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A short, silent, looping video from the app's assets (module cards).
/// Shows [placeholder] until the first frame is ready, and keeps showing it
/// if the video can't play (no video support, tests, a missing file).
class LoopVideo extends StatefulWidget {
  const LoopVideo({super.key, required this.asset, required this.placeholder, this.fit = BoxFit.cover});

  final String asset;
  final Widget placeholder;
  final BoxFit fit;

  @override
  State<LoopVideo> createState() => _LoopVideoState();
}

class _LoopVideoState extends State<LoopVideo> {
  VideoPlayerController? _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final c = VideoPlayerController.asset(
        widget.asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _c = c;
      await c.initialize();
      // Muted, so browsers allow autoplay and it never interrupts other audio.
      await c.setVolume(0);
      await c.setLooping(true);
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Placeholder stays.
    }
  }

  @override
  void dispose() {
    final c = _c;
    _c = null;
    if (c != null) {
      c.dispose().catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (!_ready || c == null || !c.value.isInitialized) return widget.placeholder;
    final size = c.value.size;
    return ClipRect(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: size.width <= 0 ? 1 : size.width,
          height: size.height <= 0 ? 1 : size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}
