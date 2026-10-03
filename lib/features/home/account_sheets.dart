import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/config.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// Profile › Account › Change password.
Future<void> showChangePasswordSheet(BuildContext context) async {
  final changed = await showAppSheet<bool>(context, const _ChangePasswordSheet());
  if (changed == true && context.mounted) {
    context.toast('Password changed');
  }
}

/// Profile › Delete account: confirm with the password (+ typing DELETE),
/// delete everything, sign out and go to Log in.
Future<void> showDeleteAccountDialog(BuildContext context) async {
  final isDemo = Store.I.current?.isDemo == true;
  final password = await showAppDialog<String>(
    context,
    _DeleteAccountDialog(isDemo: isDemo),
  );
  if (password == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final r = await Store.I.removeAccount(password);
  if (!context.mounted) return;
  if (r != AuthResult.ok) {
    context.toast(Store.authMessage(r));
    return;
  }
  context.resetTo(Routes.login);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Account deleted')));
}

/// Small red helper line under a field.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, height: 1.35, color: context.tk.dangerText),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _current.addListener(_onCurrent);
    _next.addListener(_onNext);
    _confirm.addListener(_onConfirm);
  }

  void _onCurrent() {
    if (mounted) setState(() => _currentError = null);
  }

  void _onNext() {
    if (mounted) setState(() => _nextError = null);
  }

  void _onConfirm() {
    if (mounted) setState(() => _confirmError = null);
  }

  @override
  void dispose() {
    _current.removeListener(_onCurrent);
    _next.removeListener(_onNext);
    _confirm.removeListener(_onConfirm);
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _strengthLabel(int score) {
    final labels = Demo.section('access').m('signup').ls('strengthLabels');
    if (score >= 0 && score < labels.length) return labels[score];
    return '';
  }

  bool get _canSubmit =>
      _current.text.isNotEmpty && _next.text.isNotEmpty && _confirm.text.isNotEmpty;

  bool _busy = false;

  Future<void> _submit() async {
    if (!_canSubmit || _busy) return;
    if (_next.text != _confirm.text) {
      setState(() => _confirmError = 'The new passwords don’t match.');
      return;
    }
    if (_next.text == _current.text) {
      setState(() => _nextError = 'Choose a password different from your current one.');
      return;
    }
    setState(() => _busy = true);
    final r = await Store.I.updatePassword(_current.text, _next.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == AuthResult.ok) {
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      switch (r) {
        case AuthResult.wrongPassword:
          _currentError = Store.authMessage(r);
        case AuthResult.weakPassword:
          _nextError = Store.authMessage(r);
        default:
          _currentError = Store.authMessage(r);
      }
    });
  }

  void _forgot() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.pushNamed(Routes.resetPassword);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final score = Store.passwordStrength(_next.text);
    final strong = Store.isStrongPassword(_next.text);
    final ruleText = _next.text.isEmpty
        ? '8+ characters, a number and a symbol'
        : '${_strengthLabel(score)} · 8+ characters, a number and a symbol';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Change password',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          Text(
            'Enter your current password, then choose a new one.',
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              AppTextField(
                label: 'Current password',
                hint: 'Your current password',
                controller: _current,
                password: true,
              ),
              if (_currentError != null) _ErrorText(_currentError!),
              Align(
                alignment: Alignment.centerRight,
                child: LinkText(
                  'Forgot current password?',
                  underline: true,
                  onTap: _forgot,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              AppTextField(
                label: 'New password',
                hint: 'Create a new password',
                controller: _next,
                password: true,
              ),
              if (_nextError != null) _ErrorText(_nextError!),
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
                  color: _next.text.isNotEmpty && !strong ? t.dangerText : t.textMuted,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              AppTextField(
                label: 'Confirm new password',
                hint: 'Type it again',
                controller: _confirm,
                password: true,
              ),
              if (_confirmError != null) _ErrorText(_confirmError!),
            ],
          ),
          const SizedBox(height: 2),
          PrimaryButton(
            label: 'Update password',
            leading: AppIcons.lock,
            enabled: _canSubmit,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.isDemo});

  final bool isDemo;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _word = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onChanged);
    _word.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _password.removeListener(_onChanged);
    _word.removeListener(_onChanged);
    _password.dispose();
    _word.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _password.text.isNotEmpty && _word.text.trim().toUpperCase() == 'DELETE';

  void _confirm() {
    if (!_canDelete) return;
    final acc = Store.I.current;
    if (acc == null) {
      setState(() => _error = Store.authMessage(AuthResult.noAccount));
      return;
    }
    // Offline build: check here. With a server, the server checks it.
    if (!AppConfig.hasApi && acc.password != _password.text) {
      setState(() => _error = Store.authMessage(AuthResult.wrongPassword));
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    const lost = <String>[
      'All practice history, scores and bands',
      'Your essays and speaking recordings',
      'Certificates, study plan and saved items',
    ];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            spacing: 12,
            children: [
              IconCircle(
                AppIcons.delete,
                size: 44,
                bg: t.dangerSoft,
                fg: t.dangerText,
              ),
              const Expanded(
                child: Text(
                  'Delete account?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          Text(
            'This permanently deletes your IELTS AI account from this device, including:',
            style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              for (final line in lost)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(AppIcons.close, size: 16, color: t.dangerText),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(fontSize: 14, height: 1.35, color: t.textSoft),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.dangerSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.isDemo
                  ? 'This can’t be undone. As this is the demo account, it will be restored with its demo data the next time the app launches.'
                  : 'This can’t be undone.',
              style: TextStyle(fontSize: 13, height: 1.4, color: t.dangerText),
            ),
          ),
          AppTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _password,
            password: true,
          ),
          AppTextField(
            label: 'Type DELETE to confirm',
            hint: 'DELETE',
            controller: _word,
          ),
          if (_error != null) _ErrorText(_error!),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: OutlineButtonX(
                  label: 'Cancel',
                  height: 48,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: PrimaryButton(
                  label: 'Delete',
                  height: 48,
                  bg: t.danger,
                  fg: t.isNight ? t.bg : t.surface,
                  enabled: _canDelete,
                  onTap: _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
