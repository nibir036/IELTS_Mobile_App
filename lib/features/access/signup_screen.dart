import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'legal_screen.dart';
import 'widgets.dart';

/// A3 · Sign Up (name, phone, password → OTP).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final Map<String, dynamic> _data = Demo.section('access').m('signup');
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _agreed = false;
  String? _phoneError;
  bool _phoneTaken = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onChanged);
    _phone.addListener(_onPhoneChanged);
    _password.addListener(_onPasswordChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onPhoneChanged() {
    if (!mounted) return;
    setState(() {
      _phoneError = null;
      _phoneTaken = false;
    });
  }

  void _onPasswordChanged() {
    if (!mounted) return;
    setState(() => _passwordError = null);
  }

  @override
  void dispose() {
    _name.removeListener(_onChanged);
    _phone.removeListener(_onPhoneChanged);
    _password.removeListener(_onPasswordChanged);
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String _strengthLabel(int score) {
    final labels = _data.ls('strengthLabels');
    if (score >= 0 && score < labels.length) return labels[score];
    return '';
  }

  bool _busy = false;

  bool get _canSubmit =>
      !_busy && _agreed && _phone.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await Store.I.beginSignup(
      name: _name.text,
      phone: _phone.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == AuthResult.ok) {
      final dev = Store.lastDevCode;
      if (dev != null) context.toast('Test server · code $dev');
      context.push(Routes.otp);
      return;
    }
    setState(() {
      _phoneError = null;
      _phoneTaken = false;
      _passwordError = null;
      switch (r) {
        case AuthResult.phoneTaken:
          _phoneTaken = true;
          _phoneError = 'This number already has an account.';
        case AuthResult.weakPassword:
          _passwordError = Store.authMessage(r);
        default:
          _phoneError = Store.authMessage(r);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final score = Store.passwordStrength(_password.text);
    final strong = Store.isStrongPassword(_password.text);
    final ruleText = _password.text.isEmpty
        ? '8+ characters, a number and a symbol'
        : '${_strengthLabel(score)} · 8+ characters, a number and a symbol';

    return AppScreen(
      gap: 14,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          PrimaryButton(
            label: _busy ? 'Sending code…' : 'Send verification code',
            trailing: AppIcons.forward,
            enabled: _canSubmit,
            onTap: _submit,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(fontSize: 14, color: t.textMuted),
              ),
              LinkText(
                'Log in',
                underline: true,
                onTap: () => context.replace(Routes.login),
              ),
            ],
          ),
        ],
      ),
      children: [
        TopBar(
          onBack: () => context.back(),
          center: const SegmentBar(count: 2, filled: 1, height: 5, gap: 6),
          actions: [
            Text('1 of 2', style: TextStyle(fontSize: 13, color: t.textMuted)),
          ],
        ),
        const Headline(
          'Create your\naccount',
          size: 32,
          subtitle: 'We’ll text a code to verify your number.',
        ),
        AppTextField(
          label: 'Full name',
          hint: 'Your full name',
          prefixIcon: AppIcons.person,
          controller: _name,
          keyboardType: TextInputType.name,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            AppTextField(
              label: 'Phone number',
              hint: '1XXX XXXXXX',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefix: const CountryCodePrefix(code: '+880'),
            ),
            if (_phoneError != null)
              FieldError(
                _phoneError!,
                action: _phoneTaken ? 'Log in instead' : null,
                onAction: _phoneTaken
                    ? () => context.replace(Routes.login)
                    : null,
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            AppTextField(
              label: 'Password',
              hint: 'Create a password',
              controller: _password,
              password: true,
            ),
            if (_passwordError != null) FieldError(_passwordError!),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            SegmentBar(count: 4, filled: score, height: 5, gap: 4),
            Text(
              ruleText,
              style: TextStyle(
                fontSize: 12,
                color: _password.text.isNotEmpty && !strong
                    ? t.dangerText
                    : t.textMuted,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () => setState(() => _agreed = !_agreed),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: _agreed ? t.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: _agreed
                        ? null
                        : Border.all(color: t.textMuted, width: 1.5),
                  ),
                  child: _agreed
                      ? Icon(AppIcons.check, size: 14, color: t.onPrimary)
                      : null,
                ),
                Flexible(
                  child: LegalLinksText(
                    prefix: 'I agree to the ',
                    suffix:
                        ', and to my speaking recordings being stored for feedback.',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: t.isNight ? t.text : t.textSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
