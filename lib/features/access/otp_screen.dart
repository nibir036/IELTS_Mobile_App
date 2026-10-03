import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/config.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../home/language_sheet.dart';
import 'widgets.dart';

/// A4 · OTP Verification (on-screen keypad + resend countdown).
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final Map<String, dynamic> _data = Demo.section('access').m('otp');
  late final int _length = _data.i('codeLength') > 0 ? _data.i('codeLength') : 6;
  late final int _resendSeconds =
      _data.i('resendSeconds') > 0 ? _data.i('resendSeconds') : 42;
  String _code = '';
  String? _error;
  late int _secondsLeft = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _secondsLeft = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _type(String digit) {
    if (_code.length >= _length) return;
    setState(() {
      _code = '$_code$digit';
      _error = null;
    });
  }

  void _delete() {
    if (_code.isEmpty) return;
    setState(() {
      _code = _code.substring(0, _code.length - 1);
      _error = null;
    });
  }

  bool _busy = false;

  Future<void> _resend() async {
    setState(() {
      _code = '';
      _error = null;
      _startTimer();
    });
    if (!AppConfig.hasApi) {
      context.toast('Code sent · demo code $kDemoOtp');
      return;
    }
    final r = await Store.I.resendSignupCode();
    if (!mounted) return;
    final dev = Store.lastDevCode;
    context.toast(r == AuthResult.ok
        ? (dev != null ? 'New code sent · test code $dev' : 'New code sent')
        : Store.authMessage(r));
  }

  Future<void> _verify() async {
    if (_code.length != _length || _busy) return;
    setState(() => _busy = true);
    final r = await Store.I.completeSignup(_code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == AuthResult.ok) {
      FeedbackLanguage.applyPending();
      context.resetTo(Routes.targetBand);
      return;
    }
    setState(() {
      _code = '';
      _error = r == AuthResult.invalidOtp && !AppConfig.hasApi
          ? 'That code is incorrect. Try again.'
          : Store.authMessage(r);
    });
  }

  static String _mask(String phone) {
    if (phone.length < 7) return '+880 $phone';
    return '+880 ${phone.substring(0, 4)} ••• ${phone.substring(phone.length - 3)}';
  }

  String get _countdown {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final pending = Store.I.pendingSignup;
    final ready = _code.length == _length;

    if (pending == null) {
      return AppScreen(
        gap: 16,
        children: [
          TopBar(onBack: () => context.back()),
          EmptyState(
            title: 'No sign-up in progress',
            message:
                'Start by creating your account — we’ll text a verification code to your number.',
            icon: AppIcons.lock,
            actionLabel: 'Go to sign up',
            onAction: () => context.replace(Routes.signup),
          ),
        ],
      );
    }

    return AppScreen(
      gap: 16,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      footer: _Keypad(onDigit: _type, onDelete: _delete),
      children: [
        TopBar(
          onBack: () => context.back(),
          center: const SegmentBar(count: 2, filled: 2, height: 5, gap: 6),
          actions: [
            Text('2 of 2', style: TextStyle(fontSize: 13, color: t.textMuted)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            const Text(
              'Enter the code',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                height: 1.1,
                letterSpacing: -0.8,
              ),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    text: '$_length-digit code sent to ',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: t.textMuted,
                    ),
                    children: [
                      TextSpan(
                        text: _mask(pending.phone),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: t.text,
                        ),
                      ),
                      const TextSpan(text: ' · '),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.back(),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: t.text,
                      decoration: TextDecoration.underline,
                      decorationColor: t.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            for (var i = 0; i < _length; i++)
              Expanded(
                child: _OtpBox(
                  digit: i < _code.length ? _code[i] : null,
                  active: i == _code.length,
                ),
              ),
          ],
        ),
        if (_error != null) FieldError(_error!),
        Row(
          children: [
            Expanded(
              child: Text(
                'Didn’t get it?',
                style: TextStyle(fontSize: 14, color: t.textMuted),
              ),
            ),
            if (_secondsLeft > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(AppIcons.timer, size: 16, color: t.textMuted),
                  Text(
                    'Resend in $_countdown',
                    style: TextStyle(
                      fontSize: 14,
                      color: t.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              )
            else
              LinkText('Resend code', onTap: _resend, underline: true),
          ],
        ),
        PrimaryButton(
          label: _busy ? 'Verifying…' : 'Verify & continue',
          onTap: ready && !_busy ? _verify : null,
          bg: ready ? null : (t.isNight ? t.primary : const Color(0xFFCFC2CA)),
          fg: ready ? null : (t.isNight ? t.onPrimary : const Color(0xFFFFFFFF)),
        ),
        if (!AppConfig.hasApi) const DemoHint('Demo build: use code $kDemoOtp'),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (digit != null) {
      return Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          digit!,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
      );
    }
    if (active) {
      return Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.text, width: 1.5),
        ),
        child: Container(width: 2, height: 24, color: t.alert),
      );
    }
    return SizedBox(
      height: 58,
      child: CustomPaint(
        painter: _DashedBoxPainter(
          fill: t.surface,
          stroke: t.isNight ? t.border : const Color(0xFFD4C6CF),
          radius: 16,
        ),
      ),
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter({
    required this.fill,
    required this.stroke,
    required this.radius,
  });

  final Color fill;
  final Color stroke;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + 4) < metric.length ? d + 4 : metric.length;
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBoxPainter old) =>
      old.fill != fill || old.stroke != stroke || old.radius != radius;
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onDelete});

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  static const _rows = <List<String>>[
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final row in _rows)
          Row(
            spacing: 8,
            children: [
              for (final key in row)
                Expanded(child: _key(t, key)),
            ],
          ),
      ],
    );
  }

  Widget _key(AppTokens t, String key) {
    if (key.isEmpty) return const SizedBox(height: 52);
    final isDelete = key == '<';
    return Semantics(
      button: true,
      label: isDelete ? 'Delete' : key,
      child: Material(
        color: isDelete ? Colors.transparent : t.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDelete ? onDelete : () => onDigit(key),
          child: SizedBox(
            height: 52,
            child: Center(
              child: isDelete
                  ? Icon(AppIcons.backspace, size: 22, color: t.text)
                  : Text(
                      key,
                      style: TextStyle(fontSize: 22, color: t.text),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
