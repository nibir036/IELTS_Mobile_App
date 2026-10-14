import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/services/billing_service.dart';
import '../../app/services/config.dart';
import '../../app/services/entitlements.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// The signed-in student's plan name ('Free' | 'Pro'): the server's answer
/// (Entitlements) once known, else the profile's last known plan.
String currentPlanName(Store store) {
  if (AppConfig.hasApi && (Entitlements.I.loaded || BillingService.I.hasPass)) {
    return Entitlements.I.isPro || BillingService.I.hasPass ? 'Pro' : 'Free';
  }
  final raw = store.current?.profile['plan'];
  final s = raw == null ? '' : '$raw'.trim();
  if (s.isEmpty) return 'Free';
  return s.toLowerCase() == 'pro' ? 'Pro' : s;
}

/// "3999" → "3,999".
String _groupDigits(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

const List<String> _months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// ISO time → "14 Oct 2026" (local).
String _dateLabel(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String _paidWith(String provider) => switch (provider) {
      'google_play' => 'Google Play',
      'bkash' => 'bKash',
      '' => '',
      _ => 'nextED',
    };

/// Plans: Pro passes (7, 45, 100 days; all give full access) bought once
/// through Google Play (no automatic renewal), the running pass with its
/// dates, Upgrade plan (a longer pass) and Free vs Pro.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String? _picked; // pass id; null = the default
  bool _upgrading = false;

  /// The plans content with the app's own copy (`app` blocks) applied.
  static Map<String, dynamic> _content() {
    final raw = Demo.section('home').m('plans');
    return <String, dynamic>{...raw, ...raw.m('app')};
  }

  static List<Map<String, dynamic>> _passes(Map<String, dynamic> content) => <Map<String, dynamic>>[
        for (final p in content.l('passes')) <String, dynamic>{...p, ...p.m('app')},
      ];

  @override
  void initState() {
    super.initState();
    BillingService.I.addListener(_onBilling);
    // After the first frame: load() notifies listeners straight away.
    Future<void>.microtask(() => BillingService.I.load(_passes(_content()).map((p) => p.s('playProductId'))));
  }

  @override
  void dispose() {
    BillingService.I.removeListener(_onBilling);
    super.dispose();
  }

  void _onBilling() {
    final m = BillingService.I.takeMessage();
    if (m == null || !mounted) return;
    context.toast(m);
    if (BillingService.I.hasPass && _upgrading) setState(() => _upgrading = false);
  }

  Future<void> _buy(Map<String, dynamic> pass) async {
    final err = await BillingService.I.buy(pass.s('playProductId'));
    if (err != null && mounted) context.toast(err);
  }

  Future<void> _openSupport(String number) async {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final ok = await launchUrl(Uri.parse('https://wa.me/$digits'), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) context.toast('Couldn’t open WhatsApp. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[BillingService.I, Entitlements.I]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final billing = BillingService.I;
    final content = _content();
    final all = _passes(content);
    final features = content.l('features');
    final planName = currentPlanName(store);
    final isPro = planName == 'Pro';
    final cur = content.s('currency').isEmpty ? 'BDT' : content.s('currency');
    final current = billing.current;
    final queued = current.l('queued');
    final lastEnd = queued.isNotEmpty ? queued.last.s('endsAt') : current.s('endsAt');

    // Upgrading: only the passes longer than the one held.
    final rank = all.indexWhere((p) => p.s('id') == billing.highestPassId);
    final higher = rank < 0 ? all : all.sublist(rank + 1);
    final canUpgrade = isPro && billing.canUpgrade && higher.isNotEmpty;
    final choosing = !isPro || (_upgrading && canUpgrade);
    final shown = isPro ? (choosing ? higher : const <Map<String, dynamic>>[]) : all;

    final pickedId = _picked ?? (isPro ? (higher.isEmpty ? '' : higher.first.s('id')) : content.s('defaultPass'));
    var pass = shown.isEmpty ? <String, dynamic>{} : shown.first;
    for (final p in shown) {
      if (p.s('id') == pickedId) pass = p;
    }

    Widget? footer;
    if (choosing && pass.isNotEmpty) {
      final buying = billing.busy;
      final label = buying
          ? 'Opening Google Play…'
          : isPro
              ? 'Upgrade to ${pass.s('name')} · $cur ${_groupDigits(pass.i('price'))}'
              : '${content.s('cta').isEmpty ? 'Get Pro' : content.s('cta')} · $cur ${_groupDigits(pass.i('price'))}';
      footer = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          PrimaryButton(
            label: label,
            leading: buying ? null : AppIcons.sparkle,
            enabled: !buying,
            onTap: buying ? null : () => _buy(pass),
          ),
          Text(
            billing.pending
                ? 'Payment pending. Your pass starts as soon as Google Play confirms it.'
                : content.s('ctaNote'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.35, color: t.textMuted),
          ),
        ],
      );
    }

    return AppScreen(
      gap: 14,
      footer: footer,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        TopBar(
          title: 'Plans',
          subtitle: 'You’re on $planName',
          onBack: () => context.back(),
        ),
        if (isPro)
          _ProCard(
            name: current.s('name'),
            startedAt: current.s('startedAt'),
            endsAt: lastEnd,
            paidWith: _paidWith(current.s('paidWith')),
            queued: queued,
            note: content.s('proRenewalNote'),
          )
        else
          HeroCard(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(
                  content.s('headline'),
                  style: TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w600, color: t.heroText),
                ),
                Text(
                  content.s('subhead'),
                  style: TextStyle(fontSize: 14, height: 1.4, color: t.heroMuted),
                ),
              ],
            ),
          ),
        if (canUpgrade && !_upgrading)
          SoftButton(
            label: 'Upgrade plan',
            leading: AppIcons.trendUp,
            expand: true,
            height: 52,
            onTap: () => setState(() {
              _upgrading = true;
              _picked = null;
            }),
          ),
        if (isPro && choosing) ...[
          const SectionTitle('Upgrade plan'),
          Text(
            'Your new pass starts when your current one ends${lastEnd.isEmpty ? '' : ' on ${_dateLabel(lastEnd)}'}, so you don’t lose any days.',
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
          ),
        ],
        for (final p in shown)
          _PassCard(
            pass: p,
            currency: cur,
            selected: p.s('id') == pass.s('id'),
            onTap: () => setState(() => _picked = p.s('id')),
          ),
        if (content.ls('allAccess').isNotEmpty)
          AppCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(content.s('allAccessTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                for (final h in content.ls('allAccess'))
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(AppIcons.checkCircle, size: 18, color: t.iconAccent),
                      ),
                      Expanded(child: Text(h, style: TextStyle(fontSize: 14, height: 1.35, color: t.textSoft))),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 2),
        const SectionTitle('Free vs Pro'),
        _ComparisonTable(features: features),
        Text(
          content.s('pricingNote'),
          style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
        ),
        if (!isPro && content.s('supportWhatsapp').isNotEmpty)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openSupport(content.s('supportWhatsapp')),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: content.s('supportLine').isEmpty
                          ? 'Facing issues with payment system? Contact our tech support at '
                          : '${content.s('supportLine')} ',
                    ),
                    TextSpan(
                      text: 'WhatsApp',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.text,
                        decoration: TextDecoration.underline,
                        decorationColor: t.text,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.45, color: t.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pro: the running pass, its start and end dates, how it was paid and any
/// pass queued after it. Passes bought in the app never renew by themselves.
class _ProCard extends StatelessWidget {
  const _ProCard({
    required this.name,
    required this.startedAt,
    required this.endsAt,
    required this.paidWith,
    required this.queued,
    required this.note,
  });

  final String name;
  final String startedAt;
  final String endsAt;
  final String paidWith;
  final List<Map<String, dynamic>> queued;
  final String note;

  Widget _dateBox(BuildContext context, String label, String iso) {
    final t = context.tk;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: t.heroDivider, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: t.heroMuted)),
            Text(
              iso.isEmpty ? '-' : _dateLabel(iso),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.heroText),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hasDates = startedAt.isNotEmpty && endsAt.isNotEmpty;
    return HeroCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Row(
            spacing: 10,
            children: [
              Icon(AppIcons.verified, size: 22, color: t.peach),
              Expanded(
                child: Text(
                  name.isEmpty ? 'You’re on Pro' : 'Pro · $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: t.heroText),
                ),
              ),
              const Tag('Current plan', tone: TagTone.hero),
            ],
          ),
          if (hasDates)
            Row(
              spacing: 10,
              children: [
                _dateBox(context, 'Started', startedAt),
                _dateBox(context, 'Ends', endsAt),
              ],
            )
          else
            Text(
              'Unlimited mocks, AI feedback and the full library are unlocked.',
              style: TextStyle(fontSize: 14, height: 1.4, color: t.heroMuted),
            ),
          for (final q in queued)
            Text(
              'Next: ${q.s('name')} from ${_dateLabel(q.s('startsAt'))}',
              style: TextStyle(fontSize: 13, height: 1.4, color: t.heroMuted),
            ),
          Container(height: 1, color: t.heroDivider),
          Text(
            [
              if (paidWith.isNotEmpty) 'Paid with $paidWith',
              hasDates ? 'Doesn’t renew by itself' : note,
            ].where((x) => x.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12, height: 1.4, color: t.heroMuted),
          ),
        ],
      ),
    );
  }
}

/// One Pro pass: was / now price, saving, price per day and a pitch line.
class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass, required this.currency, required this.selected, this.onTap});

  final Map<String, dynamic> pass;
  final String currency;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final price = pass.i('price');
    final was = pass.i('priceWas');
    final days = pass.i('days');
    // Rounded up, so "a day" is never cheaper than it really is.
    final perDay = days > 0 ? (price / days).ceil() : 0;
    final save = was > price
        ? (pass.s('save') == 'amount'
            ? 'Save $currency ${_groupDigits(was - price)}'
            : 'Save ${((1 - price / was) * 100).floor()}%')
        : '';
    final badge = pass.s('badge');
    final note = pass.s('perDayNote');
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      borderColor: selected ? t.text : t.border,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(
                selected ? AppIcons.radioOn : AppIcons.circle,
                size: 22,
                color: selected ? t.text : t.textFaint,
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: pass.s('name')),
                      if (badge.isEmpty && pass.s('label').isNotEmpty)
                        TextSpan(
                          text: ' · ${pass.s('label')}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: t.textMuted),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              if (badge.isNotEmpty)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Tag(badge, tone: badge == 'Most popular' ? TagTone.primary : TagTone.accent),
                  ),
                ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (was > price)
                Text(
                  '$currency ${_groupDigits(was)}',
                  style: TextStyle(
                    fontSize: 15,
                    color: t.textMuted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: t.textMuted,
                  ),
                ),
              Text(
                '$currency ${_groupDigits(price)}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
              ),
              if (save.isNotEmpty)
                FittedBox(fit: BoxFit.scaleDown, child: Tag(save, tone: TagTone.accent, height: 24)),
            ],
          ),
          if (perDay > 0)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: badge.isEmpty ? 'Just ' : 'Only '),
                  TextSpan(
                    text: '$currency $perDay a day',
                    style: TextStyle(fontWeight: FontWeight.w600, color: t.text),
                  ),
                  if (note.isNotEmpty) TextSpan(text: ', $note'),
                  const TextSpan(text: '.'),
                ],
              ),
              style: TextStyle(fontSize: 14, height: 1.35, color: t.textSoft),
            ),
          if (pass.s('pitch').isNotEmpty)
            Text(
              '“${pass.s('pitch')}”',
              style: TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic, color: t.textMuted),
            ),
          if (pass.s('compare').isNotEmpty)
            Text(pass.s('compare'), style: TextStyle(fontSize: 12, height: 1.35, color: t.textMuted)),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.features});

  final List<Map<String, dynamic>> features;

  Widget _cell(BuildContext context, String value, {required bool pro}) {
    final t = context.tk;
    Widget child;
    if (value == 'yes') {
      child = Icon(AppIcons.check, size: 18, color: pro ? t.text : t.textMuted);
    } else if (value == 'no') {
      child = Icon(AppIcons.remove, size: 18, color: t.textFaint);
    } else {
      child = Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: pro ? FontWeight.w500 : FontWeight.w400,
          color: pro ? t.text : t.textMuted,
        ),
      );
    }
    return SizedBox(width: 76, child: Center(child: child));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final header = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.textMuted);
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: Text('Feature', style: header)),
                SizedBox(width: 76, child: Center(child: Text('Free', style: header))),
                SizedBox(width: 76, child: Center(child: Text('Pro', style: header))),
              ],
            ),
          ),
          for (var i = 0; i < features.length; i++) ...[
            const Hairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      features[i].s('label'),
                      style: TextStyle(fontSize: 14, height: 1.3, color: t.text),
                    ),
                  ),
                  _cell(context, features[i].s('free'), pro: false),
                  _cell(context, features[i].s('pro'), pro: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
