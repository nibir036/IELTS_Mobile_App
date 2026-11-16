import 'package:flutter/material.dart';

import '../../app/data/countries.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// A3a · Where are you? The first sign-up step: Bangladesh signs up with a
/// mobile number (code by SMS), the Gulf countries with an email address
/// (code by email). The choice is passed on in [Store.signupCountry].
class CountryScreen extends StatelessWidget {
  const CountryScreen({super.key});

  void _pick(BuildContext context, SignupCountry c) {
    Store.signupCountry = c.code;
    context.push(Routes.signup);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppScreen(
      gap: 12,
      children: [
        TopBar(onBack: () => context.back()),
        const Headline(
          'Where are\nyou now?',
          size: 32,
          subtitle: 'Choose the country you live in. It decides how we verify your account.',
        ),
        const SizedBox(height: 4),
        for (final c in kSignupCountries)
          AppCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => _pick(context, c),
            child: Row(
              spacing: 12,
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 26)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      Text(
                        c.usesEmail ? 'Sign up with your email' : 'Sign up with your mobile number',
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(c.usesEmail ? AppIcons.email : AppIcons.phone, size: 20, color: t.textMuted),
                Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
              ],
            ),
          ),
      ],
    );
  }
}
