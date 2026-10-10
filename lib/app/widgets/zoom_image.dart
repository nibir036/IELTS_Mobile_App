import 'package:flutter/material.dart';

import '../services/media.dart';
import 'app_icons.dart';

/// Full-screen image viewer for exam pictures (Writing Task 1 charts, maps,
/// diagrams): pinch or the +/- buttons to zoom, drag to move, double-tap to
/// zoom in on a spot (again to fit), "Fit" to reset. White page so the
/// picture reads as printed, in both themes.
///
/// [initialScale] / [initialFocus] open it already zoomed in on a point
/// (as fractions 0..1 of the picture's box) - used when the student pinches
/// the small picture on the page (see [PinchToZoomImage]).
Future<void> showZoomImage(
  BuildContext context,
  String image, {
  String title = '',
  double initialScale = 1,
  Offset initialFocus = const Offset(0.5, 0.5),
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => ZoomImagePage(
        image: image,
        title: title,
        initialScale: initialScale,
        initialFocus: initialFocus,
      ),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class ZoomImagePage extends StatefulWidget {
  const ZoomImagePage({
    super.key,
    required this.image,
    this.title = '',
    this.initialScale = 1,
    this.initialFocus = const Offset(0.5, 0.5),
  });

  final String image;
  final String title;
  final double initialScale;
  final Offset initialFocus;

  @override
  State<ZoomImagePage> createState() => _ZoomImagePageState();
}

class _ZoomImagePageState extends State<ZoomImagePage> with SingleTickerProviderStateMixin {
  static const double _min = 1;
  static const double _max = 6;
  static const double _step = 1.5;
  static const Color _ink = Color(0xFF151515);

  final TransformationController _tc = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..addListener(_tick);
  Animation<Matrix4>? _to;
  Offset? _tapAt;
  Size _view = Size.zero;
  bool _startedZoom = false;

  double get _scale => _tc.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _tick() {
    final to = _to;
    if (to != null) _tc.value = to.value;
  }

  void _animateTo(Matrix4 m) {
    _to = Matrix4Tween(begin: _tc.value, end: m).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  /// Zoom to [scale] keeping [focus] (a point in the viewer) where it is.
  void _zoomTo(double scale, Offset focus) {
    final s = scale.clamp(_min, _max).toDouble();
    if (s <= _min + 0.01) {
      _animateTo(Matrix4.identity());
      return;
    }
    final scene = _tc.toScene(focus);
    _animateTo(_matrix(s, focus.dx - scene.dx * s, focus.dy - scene.dy * s));
  }

  /// Scale [s] with offset (tx, ty), kept so the picture still covers the
  /// view (no drifting off-screen).
  Matrix4 _matrix(double s, double tx, double ty) {
    final w = _view.width, h = _view.height;
    return Matrix4.diagonal3Values(s, s, 1)
      ..setTranslationRaw(tx.clamp(w - w * s, 0).toDouble(), ty.clamp(h - h * s, 0).toDouble(), 0);
  }

  Offset get _centre => Offset(_view.width / 2, _view.height / 2);

  void _doubleTap() {
    final at = _tapAt ?? _centre;
    _zoomTo(_scale > 1.4 ? _min : 2.5, at);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_scale * 100).round();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(AppIcons.close, color: _ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _ink),
                    ),
                  ),
                  Text('$pct%', style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B))),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  _view = Size(c.maxWidth, c.maxHeight);
                  if (!_startedZoom && widget.initialScale > 1.05) {
                    _startedZoom = true;
                    final at = Offset(widget.initialFocus.dx * c.maxWidth, widget.initialFocus.dy * c.maxHeight);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _zoomTo(widget.initialScale, at);
                    });
                  }
                  return GestureDetector(
                    onDoubleTapDown: (d) => _tapAt = d.localPosition,
                    onDoubleTap: _doubleTap,
                    child: InteractiveViewer(
                      transformationController: _tc,
                      minScale: _min,
                      maxScale: _max,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: c.maxWidth,
                        height: c.maxHeight,
                        child: MediaImage(
                          widget.image,
                          fit: BoxFit.contain,
                          semanticLabel: widget.title.isEmpty ? 'Task picture' : widget.title,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text('Couldn\'t load the picture.', style: TextStyle(color: _ink)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  _ZoomButton(
                    icon: AppIcons.zoomOut,
                    label: 'Zoom out',
                    onTap: _scale <= _min + 0.01 ? null : () => _zoomTo(_scale / _step, _centre),
                  ),
                  _ZoomButton(
                    icon: AppIcons.fitScreen,
                    label: 'Fit to screen',
                    text: 'Fit',
                    onTap: _scale <= _min + 0.01 ? null : () => _animateTo(Matrix4.identity()),
                  ),
                  _ZoomButton(
                    icon: AppIcons.zoomIn,
                    label: 'Zoom in',
                    onTap: _scale >= _max - 0.01 ? null : () => _zoomTo(_scale * _step, _centre),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Pinch or double-tap to zoom · drag to move',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.label, this.text, this.onTap});

  final IconData icon;
  final String label;
  final String? text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final fg = on ? const Color(0xFF151515) : const Color(0xFFB5B5B5);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: text == null ? 14 : 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(icon, size: 22, color: fg),
                if (text != null) Text(text!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a small exam picture on a page: pinching it (two fingers moving
/// apart) opens the full-screen viewer already zoomed in on the pinched
/// spot, and a tap opens it at full size. Uses raw pointer events, so one-
/// finger scrolling of the page around it is not affected.
class PinchToZoomImage extends StatefulWidget {
  const PinchToZoomImage({super.key, required this.image, required this.child, this.title = ''});

  final String image;
  final String title;
  final Widget child;

  @override
  State<PinchToZoomImage> createState() => _PinchToZoomImageState();
}

class _PinchToZoomImageState extends State<PinchToZoomImage> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _startGap;
  bool _opened = false;

  double _gap() {
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _startGap = _gap();
      _opened = false;
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final start = _startGap;
    if (_pointers.length < 2 || start == null || start < 1 || _opened) return;
    final scale = _gap() / start;
    if (scale < 1.12) return; // a real pinch-out, not jitter
    _opened = true;
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    final p = _pointers.values.take(2).toList();
    final mid = (p[0] + p[1]) / 2;
    final focus = size.isEmpty
        ? const Offset(0.5, 0.5)
        : Offset((mid.dx / size.width).clamp(0.0, 1.0), (mid.dy / size.height).clamp(0.0, 1.0));
    _pointers.clear();
    _startGap = null;
    showZoomImage(context, widget.image, title: widget.title, initialScale: 2, initialFocus: focus);
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _startGap = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: GestureDetector(
        onTap: () => showZoomImage(context, widget.image, title: widget.title),
        child: widget.child,
      ),
    );
  }
}
