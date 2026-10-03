import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/kit.dart';
import '../home/language_sheet.dart';
import 'legal_screen.dart';
import 'widgets.dart';

/// A2 · Login (phone number + password).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _demoPhone = '01734519208';
  static const String _demoPassword = 'Demo@1234';

  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _keepSignedIn = true;
  String? _phoneError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onChanged);
    _password.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      _phoneError = null;
      _passwordError = null;
    });
  }

  @override
  void dispose() {
    _phone.removeListener(_onChanged);
    _password.removeListener(_onChanged);
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _busy = false;

  bool get _canSubmit =>
      !_busy && _phone.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _fillDemo() {
    _phone.text = _demoPhone;
    _password.text = _demoPassword;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await Store.I.signIn(
      _phone.text,
      _password.text,
      keepSignedIn: _keepSignedIn,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == AuthResult.ok) {
      FeedbackLanguage.applyPending();
      final acc = Store.I.current;
      if (acc != null && !acc.onboarded) {
        context.resetTo(Routes.targetBand);
      } else {
        context.resetTo(Routes.home);
      }
      return;
    }
    setState(() {
      if (r == AuthResult.wrongPassword) {
        _passwordError = Store.authMessage(r);
        _phoneError = null;
      } else {
        _phoneError = Store.authMessage(r);
        _passwordError = null;
      }
    });
  }

  Future<void> _openLanguage() async {
    await showLanguageSheet(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final data = Demo.section('access').m('login');
    final lineColor = t.isNight ? t.surface : t.border;

    return AppScreen(
      gap: 16,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      footer: const LegalLinksText(),
      children: [
        Row(
          children: [
            const BrandMark(size: 36),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'IELTS AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Material(
              color: t.surface,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openLanguage,
                child: Container(
                  height: 32,
                  constraints: const BoxConstraints(maxWidth: 170),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: Text(
                    FeedbackLanguage.current != 'en'
                        ? FeedbackLanguage.pillLabel
                        : data.s('language'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: HeroCard(
            radius: 32,
            padding: const EdgeInsets.all(22),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(
                  'Welcome\nback.',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                    letterSpacing: -1,
                    color: t.heroText,
                  ),
                ),
                Text(
                  'Pick up where you left off.',
                  style: TextStyle(
                    fontSize: 15,
                    color: t.isNight ? t.heroText : t.textSoft,
                  ),
                ),
              ],
                  ),
                ),
              ],
            ),
          ),
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
            if (_phoneError != null) FieldError(_phoneError!),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            AppTextField(
              label: 'Password',
              hint: 'Your password',
              controller: _password,
              password: true,
            ),
            if (_passwordError != null) FieldError(_passwordError!),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: CheckRow(
                value: _keepSignedIn,
                onChanged: (v) => setState(() => _keepSignedIn = v),
                label: 'Keep me signed in',
              ),
            ),
            LinkText(
              'Forgot password?',
              onTap: () => context.push(Routes.resetPassword),
            ),
          ],
        ),
        PrimaryButton(
          label: _busy ? 'Logging in…' : 'Log in',
          enabled: _canSubmit,
          onTap: _submit,
        ),
        _DemoAccountCard(onTap: _fillDemo),
        Row(
          spacing: 12,
          children: [
            Expanded(child: Container(height: 1, color: lineColor)),
            Text(
              'New to IELTS AI?',
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
            Expanded(child: Container(height: 1, color: lineColor)),
          ],
        ),
        OutlineButtonX(
          label: 'Create an account',
          onTap: () => context.push(Routes.signup),
        ),
      ],
    );
  }
}

/// Subtle "Demo account" line — tap to fill both fields.
class _DemoAccountCard extends StatelessWidget {
  const _DemoAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.isNight ? t.surface : t.raised,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  'Demo account · 01734 519208 · Demo@1234',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              Text(
                'Tap to fill',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: t.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
