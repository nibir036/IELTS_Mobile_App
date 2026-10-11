import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// kv key: the student asked to be told when Pro launches.
const String kPlansNotifyKey = 'plans.notify';

/// The signed-in student's plan name ('Free' | 'Pro').
String currentPlanName(Store store) {
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

/// Plans: Pro passes (1 week, 1 month, 3 months; all give full access) at
/// launch prices, and Free vs Pro. No checkout yet: the button opens a
/// "Payments open soon" sheet with a notify-me toggle.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String? _picked; // pass id; null = the content's default

  void _openUpgrade(Map<String, dynamic> content, Map<String, dynamic> pass) {
    final cur = content.s('currency');
    showAppSheet<void>(
      context,
      _NotifySheet(
        copy: content.m('comingSoon'),
        summary: '${pass.s('name')} · $cur ${_groupDigits(pass.i('price'))} (${content.s('pricingLabel').toLowerCase()})',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final content = Demo.section('home').m('plans');
    final passes = content.l('passes');
    final features = content.l('features');
    final planName = currentPlanName(store);
    final isPro = planName == 'Pro';
    final notify = store.kv<bool>(kPlansNotifyKey) ?? false;
    final cur = content.s('currency');

    final pickedId = _picked ?? content.s('defaultPass');
    var pass = passes.isEmpty ? <String, dynamic>{} : passes.first;
    for (final p in passes) {
      if (p.s('id') == pickedId) pass = p;
    }

    Widget? footer;
    if (!isPro && pass.isNotEmpty) {
      footer = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          PrimaryButton(
            label: content.s('cta').isEmpty ? 'Upgrade to Pro' : content.s('cta'),
            leading: AppIcons.sparkle,
            onTap: () => _openUpgrade(content, pass),
          ),
          Text(
            notify ? 'We’ll notify you when payments open' : content.s('ctaNote'),
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
          HeroCard(
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
                    const Expanded(
                      child: Text(
                        'You’re on Pro',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Tag('Current plan', tone: TagTone.hero),
                  ],
                ),
                Text(
                  'Unlimited mocks, AI feedback and the full library are unlocked.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: t.heroMuted),
                ),
                Container(height: 1, color: t.heroDivider),
                Text(
                  content.s('proRenewalNote'),
                  style: TextStyle(fontSize: 12, height: 1.4, color: t.heroMuted),
                ),
              ],
            ),
          )
        else
          HeroCard(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                if (content.s('launchEnds').isNotEmpty)
                  // Not a Tag: its text must wrap on narrow screens / large text.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 5,
                      children: [
                        Icon(AppIcons.hourglass, size: 14, color: t.isNight ? t.primary : t.text),
                        Flexible(
                          child: Text(
                            '${content.s('pricingLabel')} ends ${content.s('launchEnds')}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.isNight ? t.primary : t.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
        for (final p in passes)
          _PassCard(
            pass: p,
            currency: cur,
            selected: !isPro && p.s('id') == pass.s('id'),
            onTap: isPro ? null : () => setState(() => _picked = p.s('id')),
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
      ],
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

/// "Payments open soon" + notify-me toggle (kv `plans.notify`).
class _NotifySheet extends StatefulWidget {
  const _NotifySheet({required this.copy, required this.summary});

  final Map<String, dynamic> copy;
  final String summary;

  @override
  State<_NotifySheet> createState() => _NotifySheetState();
}

class _NotifySheetState extends State<_NotifySheet> {
  late bool _notify;

  @override
  void initState() {
    super.initState();
    _notify = Store.I.kv<bool>(kPlansNotifyKey) ?? false;
  }

  void _set(bool v) {
    Store.I.setKv(kPlansNotifyKey, v);
    setState(() => _notify = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final copy = widget.copy;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const SizedBox(height: 4),
          Row(
            spacing: 12,
            children: [
              const IconCircle(AppIcons.hourglass, size: 44),
              Expanded(
                child: Text(
                  copy.s('title'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          Text(
            copy.s('body'),
            style: TextStyle(fontSize: 14, height: 1.45, color: t.textSoft),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Tag(widget.summary, tone: TagTone.soft),
          ),
          AppCard(
            radius: 20,
            color: t.surfaceAlt2,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            onTap: () => _set(!_notify),
            child: Row(
              spacing: 12,
              children: [
                Icon(AppIcons.bell, size: 20, color: t.text),
                Expanded(
                  child: Text(
                    copy.s('toggleLabel'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                PillSwitch(value: _notify, onChanged: _set),
              ],
            ),
          ),
          if (_notify)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(AppIcons.checkCircle, size: 18, color: t.iconAccent),
                Expanded(
                  child: Text(
                    copy.s('confirmation'),
                    style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 2),
          PrimaryButton(
            label: 'Done',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
