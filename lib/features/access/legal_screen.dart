import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/share_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// Opens the Terms of Use (`doc: 'terms'`) or Privacy Policy (`'privacy'`).
void openLegal(BuildContext context, String doc) {
  context.push(Routes.legal, args: <String, dynamic>{'doc': doc});
}

/// Legal · Terms of Use & Privacy Policy (public, works logged-out).
/// Args: `{'doc': 'terms' | 'privacy'}`. Copy lives in access.json › legal.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  static const List<String> _docs = <String>['terms', 'privacy'];
  static const List<String> _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  int _index = 0;
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final doc = context.routeArgs['doc'];
    _index = doc == 'privacy' ? 1 : 0;
  }

  String _fullDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final legal = Demo.section('access').m('legal');
    final doc = legal.m(_docs[_index]);
    final email = legal.s('contactEmail');
    final sections = doc.l('sections');

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: 'Legal',
          subtitle: 'IELTS AI by nextED',
          onBack: () => context.back(),
        ),
        SegmentedTabs(
          labels: const <String>['Terms of Use', 'Privacy Policy'],
          index: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
        AppCard(
          radius: 20,
          color: t.accentSoft,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(AppIcons.info, size: 20, color: t.text),
              Expanded(
                child: Text(
                  legal.s('draftNote'),
                  style: TextStyle(fontSize: 13, height: 1.45, color: t.text),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text(
                doc.s('title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.6,
                ),
              ),
              Text(
                'Last updated ${_fullDate(legal.s('updated'))}',
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
            ],
          ),
        ),
        Text(
          doc.s('intro'),
          style: TextStyle(fontSize: 15, height: 1.5, color: t.textSoft),
        ),
        for (final s in sections) _LegalSection(section: s),
        AppCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListRow(
            leading: IconCircle(AppIcons.sms, size: 40),
            title: 'Contact support',
            subtitle: email,
            trailing: Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
            onTap: () => ShareService.copy(
              context,
              email,
              message: 'Email address copied',
            ),
          ),
        ),
        Text(
          'IELTS is a registered trademark of the British Council, IDP: IELTS Australia and Cambridge University Press & Assessment. IELTS AI by nextED is not affiliated with or endorsed by them.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.45, color: t.textMuted),
        ),
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final body = section.ls('body');
    final bullets = section.ls('bullets');
    final textStyle = TextStyle(fontSize: 14, height: 1.5, color: t.textSoft);
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text(
            section.s('heading'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          for (final p in body) Text(p, style: textStyle),
          for (final b in bullets)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Dot(size: 5, color: t.textMuted),
                ),
                Expanded(child: Text(b, style: textStyle)),
              ],
            ),
        ],
      ),
    );
  }
}

/// "By continuing you agree to the Terms and Privacy Policy." with the two
/// document names tappable (each opens [LegalScreen] on its tab).
class LegalLinksText extends StatefulWidget {
  const LegalLinksText({
    super.key,
    this.prefix = 'By continuing you agree to the ',
    this.termsLabel = 'Terms',
    this.middle = ' and ',
    this.privacyLabel = 'Privacy Policy',
    this.suffix = '.',
    this.style,
    this.linkColor,
    this.textAlign = TextAlign.center,
  });

  final String prefix;
  final String termsLabel;
  final String middle;
  final String privacyLabel;
  final String suffix;
  final TextStyle? style;
  final Color? linkColor;
  final TextAlign textAlign;

  @override
  State<LegalLinksText> createState() => _LegalLinksTextState();
}

class _LegalLinksTextState extends State<LegalLinksText> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()..onTap = () => openLegal(context, 'terms');
    _privacy = TapGestureRecognizer()..onTap = () => openLegal(context, 'privacy');
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final linkColor = widget.linkColor ?? t.text;
    final link = TextStyle(
      color: linkColor,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );
    return Text.rich(
      TextSpan(
        text: widget.prefix,
        children: [
          TextSpan(text: widget.termsLabel, style: link, recognizer: _terms),
          TextSpan(text: widget.middle),
          TextSpan(text: widget.privacyLabel, style: link, recognizer: _privacy),
          TextSpan(text: widget.suffix),
        ],
      ),
      textAlign: widget.textAlign,
      style: widget.style ??
          TextStyle(fontSize: 12, height: 1.5, color: t.textMuted),
    );
  }
}
