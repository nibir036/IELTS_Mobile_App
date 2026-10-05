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

/// Plans (Free vs Pro). No checkout yet: "Upgrade" opens a
/// "Payments open soon" sheet with a notify-me toggle.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  int _period = 0; // 0 monthly · 1 yearly

  bool get _yearly => _period == 1;

  String _price(Map<String, dynamic> content, Map<String, dynamic> plan) {
    final cur = content.s('currency');
    final amount = _yearly ? plan.i('priceYearly') : plan.i('priceMonthly');
    if (amount <= 0) return 'Free';
    return '$cur ${_groupDigits(amount)}';
  }

  int _yearlySavingPercent(Map<String, dynamic> plan) {
    final m = plan.i('priceMonthly');
    final y = plan.i('priceYearly');
    if (m <= 0 || y <= 0) return 0;
    final pct = ((1 - y / (m * 12)) * 100).round();
    return pct > 0 ? pct : 0;
  }

  void _openUpgrade(Map<String, dynamic> content, Map<String, dynamic> pro) {
    final summary = pro.i('priceMonthly') <= 0
        ? 'Pro'
        : 'Pro · ${_price(content, pro)}${_yearly ? ' / year' : ' / month'}'
            '${pro.b('launchPricing') ? ' (${content.s('pricingLabel').toLowerCase()})' : ''}';
    showAppSheet<void>(
      context,
      _NotifySheet(copy: content.m('comingSoon'), summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final content = Demo.section('home').m('plans');
    final plans = content.l('plans');
    final features = content.l('features');
    final planName = currentPlanName(store);
    final isPro = planName == 'Pro';
    final notify = store.kv<bool>(kPlansNotifyKey) ?? false;

    Map<String, dynamic> pro = <String, dynamic>{};
    for (final p in plans) {
      if (p.s('id') == 'pro') pro = p;
    }
    final saving = _yearlySavingPercent(pro);

    Widget? footer;
    if (!isPro && pro.isNotEmpty) {
      footer = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          PrimaryButton(
            label: 'Upgrade to Pro',
            leading: AppIcons.sparkle,
            onTap: () => _openUpgrade(content, pro),
          ),
          if (notify)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: [
                Icon(AppIcons.bellActive, size: 14, color: t.textMuted),
                Flexible(
                  child: Text(
                    'We’ll notify you when Pro launches',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ),
              ],
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Renews',
                        style: TextStyle(fontSize: 13, color: t.heroMuted),
                      ),
                    ),
                    Text(
                      '-',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.heroText),
                    ),
                  ],
                ),
                Text(
                  content.s('proRenewalNote'),
                  style: TextStyle(fontSize: 12, height: 1.4, color: t.heroMuted),
                ),
              ],
            ),
          ),
        SegmentedTabs(
          labels: <String>[
            'Monthly',
            saving > 0 ? 'Yearly · save $saving%' : 'Yearly',
          ],
          index: _period,
          onChanged: (i) => setState(() => _period = i),
        ),
        for (final plan in plans)
          _PlanCard(
            plan: plan,
            price: _price(content, plan),
            period: plan.i('priceMonthly') <= 0 ? 'forever' : (_yearly ? 'per year' : 'per month'),
            perMonthNote: _yearly && plan.i('priceYearly') > 0
                ? '≈ ${content.s('currency')} ${_groupDigits((plan.i('priceYearly') / 12).round())} a month'
                : null,
            launchLabel: plan.b('launchPricing') ? content.s('pricingLabel') : null,
            current: plan.s('name').toLowerCase() == planName.toLowerCase(),
          ),
        const SizedBox(height: 2),
        const SectionTitle('Compare plans'),
        _ComparisonTable(features: features),
        Text(
          content.s('pricingNote'),
          style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.period,
    required this.current,
    this.perMonthNote,
    this.launchLabel,
  });

  final Map<String, dynamic> plan;
  final String price;
  final String period;
  final bool current;
  final String? perMonthNote;
  final String? launchLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final highlights = plan.ls('highlights');
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      borderColor: current ? t.text : t.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  plan.s('name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
              ),
              if (launchLabel != null || current)
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        if (launchLabel != null)
                          Tag(launchLabel!, tone: TagTone.accent),
                        if (current)
                          const Tag('Current plan', tone: TagTone.primary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Text(
            plan.s('tagline'),
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                price,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.6),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(period, style: TextStyle(fontSize: 13, color: t.textMuted)),
              ),
            ],
          ),
          if (perMonthNote != null)
            Text(perMonthNote!, style: TextStyle(fontSize: 12, color: t.textMuted)),
          Container(height: 1, color: t.divider),
          for (final h in highlights)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(AppIcons.checkCircle, size: 18, color: t.iconAccent),
                ),
                Expanded(
                  child: Text(
                    h,
                    style: TextStyle(fontSize: 14, height: 1.35, color: t.textSoft),
                  ),
                ),
              ],
            ),
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
