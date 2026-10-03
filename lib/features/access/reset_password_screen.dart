import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/config.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// A5 · Forgot / Reset Password — 3 local steps: Phone → Code → New password.
///
/// Step 1 → `Store.startReset`, step 2 → `Store.verifyResetOtp` (demo code
/// [kDemoOtp]), step 3 → `Store.finishReset`, then back to Log in.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final Map<String, dynamic> _data = Demo.section('access').m('resetPassword');
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _newPass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  int _step = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_refresh);
    _code.addListener(_refresh);
    _newPass.addListener(_refresh);
    _confirm.addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _error = null);
  }

  @override
  void dispose() {
    _phone.removeListener(_refresh);
    _code.removeListener(_refresh);
    _newPass.removeListener(_refresh);
    _confirm.removeListener(_refresh);
    _phone.dispose();
    _code.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_step > 0) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      context.back();
    }
  }

  static String _mask(String? phone) {
    if (phone == null || phone.isEmpty) return 'your number';
    if (phone.length < 7) return '+880 $phone';
    return '+880 ${phone.substring(0, 4)} ••• ${phone.substring(phone.length - 3)}';
  }

  bool get _passwordOk =>
      Store.isStrongPassword(_newPass.text) && _newPass.text == _confirm.text;

  bool _busy = false;

  Future<AuthResult> _run(Future<AuthResult> Function() task) async {
    setState(() => _busy = true);
    final r = await task();
    if (mounted) setState(() => _busy = false);
    return r;
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final r = await _run(() => Store.I.beginReset(_phone.text));
    if (!mounted) return;
    if (r != AuthResult.ok) {
      setState(() => _error = Store.authMessage(r));
      return;
    }
    final dev = Store.lastDevCode;
    if (AppConfig.hasApi && dev != null) context.toast('Test server · code $dev');
    _code.clear();
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _resendCode() async {
    if (!AppConfig.hasApi) {
      context.toast('Code sent · demo code $kDemoOtp');
      return;
    }
    final r = await Store.I.resendResetCode();
    if (!mounted) return;
    final dev = Store.lastDevCode;
    context.toast(r == AuthResult.ok
        ? (dev != null ? 'New code sent · test code $dev' : 'New code sent')
        : Store.authMessage(r));
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
    final r = await _run(() => Store.I.checkResetCode(_code.text.trim()));
    if (!mounted) return;
    if (r != AuthResult.ok) {
      _code.clear();
      setState(() => _error = AppConfig.hasApi ? Store.authMessage(r) : 'That code is incorrect. Try again.');
      return;
    }
    _newPass.clear();
    _confirm.clear();
    setState(() {
      _step = 2;
      _error = null;
    });
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    if (_newPass.text != _confirm.text) {
      setState(() => _error = 'The passwords don’t match.');
      return;
    }
    final r = await _run(() => Store.I.completeReset(_newPass.text));
    if (!mounted) return;
    if (r != AuthResult.ok) {
      setState(() => _error = r == AuthResult.noAccount
          ? 'Your reset session expired. Start again.'
          : Store.authMessage(r));
      return;
    }
    // With a server the reset also signs in.
    final acc = Store.I.current;
    if (acc != null) {
      context.toast('Password updated');
      context.resetTo(acc.onboarded ? Routes.home : Routes.targetBand);
      return;
    }
    context.toast('Password updated — log in');
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      context.replace(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _data.l('steps');
    final String cta;
    final VoidCallback? onCta;
    switch (_step) {
      case 0:
        cta = 'Send code';
        onCta = _phone.text.trim().isNotEmpty ? _sendCode : null;
      case 1:
        cta = 'Verify code';
        onCta = _code.text.trim().length == 6 ? _verifyCode : null;
      default:
        cta = 'Update password';
        onCta = _passwordOk ? _finish : null;
    }

    return AppScreen(
      gap: 16,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      footer: PrimaryButton(
        label: _busy ? 'Please wait…' : cta,
        onTap: _busy ? null : onCta,
        enabled: onCta != null && !_busy,
      ),
      children: [
        TopBar(
          onBack: _onBack,
          center: const Text(
            'Reset password',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        _Stepper(steps: steps, current: _step),
        ..._stepBody(context),
      ],
    );
  }

  List<Widget> _stepBody(BuildContext context) {
    final t = context.tk;
    final masked = _mask(Store.I.pendingResetPhone);
    switch (_step) {
      case 0:
        return [
          _Title(
            title: 'Forgot your\npassword?',
            subtitle: 'Enter your phone number and we’ll text you a code.',
          ),
          AppTextField(
            key: const ValueKey('reset-phone'),
            label: 'Phone number',
            hint: '1XXX XXXXXX',
            controller: _phone,
            keyboardType: TextInputType.phone,
            prefix: const CountryCodePrefix(code: '+880'),
          ),
          if (_error != null) FieldError(_error!),
        ];
      case 1:
        return [
          _Title(
            title: 'Enter the\ncode',
            subtitle: '6-digit code sent to $masked.',
          ),
          AppTextField(
            key: const ValueKey('reset-code'),
            label: 'Verification code',
            hint: '6-digit code',
            controller: _code,
            keyboardType: TextInputType.number,
            prefixIcon: AppIcons.sms,
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
              LinkText(
                'Resend code',
                underline: true,
                onTap: _resendCode,
              ),
            ],
          ),
          if (!AppConfig.hasApi)
            const DemoHint(
              'Demo build: use code $kDemoOtp',
              align: TextAlign.start,
            ),
        ];
      default:
        final rules = PasswordRules(_newPass.text);
        final match =
            _newPass.text.isNotEmpty && _newPass.text == _confirm.text;
        return [
          _Title(
            title: 'Create a new\npassword',
            subtitle: 'Your number $masked is verified.',
          ),
          AppTextField(
            key: const ValueKey('reset-new'),
            label: 'New password',
            hint: 'New password',
            controller: _newPass,
            password: true,
          ),
          AppTextField(
            key: const ValueKey('reset-confirm'),
            label: 'Confirm new password',
            hint: 'Repeat new password',
            controller: _confirm,
            password: true,
          ),
          if (_error != null) FieldError(_error!),
          AppCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                _RuleRow(label: 'At least 8 characters', met: rules.longEnough),
                _RuleRow(label: 'Contains a number', met: rules.hasNumber),
                _RuleRow(label: 'Contains a symbol (! @ # …)', met: rules.hasSymbol),
                _RuleRow(label: 'Both passwords match', met: match),
              ],
            ),
          ),
        ];
    }
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            height: 1.1,
            letterSpacing: -0.7,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: context.tk.textMuted),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.steps, required this.current});

  final List<Map<String, dynamic>> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Row(
                spacing: 8,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i <= current ? t.primary : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: i < current
                        ? Icon(AppIcons.check, size: 13, color: t.onPrimary)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: i == current ? t.onPrimary : t.textMuted,
                            ),
                          ),
                  ),
                  Flexible(
                    child: Text(
                      steps[i].s('label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: i == current ? t.text : t.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 10,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: met ? t.primary : null,
            shape: BoxShape.circle,
            border: met
                ? null
                : Border.all(
                    color: t.isNight ? t.border : const Color(0xFFCFC2CA),
                    width: 1.5,
                  ),
          ),
          child: met ? Icon(AppIcons.check, size: 11, color: t.onPrimary) : null,
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: met
                  ? t.text
                  : (t.isNight ? t.textMuted : const Color(0xFF8A8290)),
            ),
          ),
        ),
      ],
    );
  }
}
