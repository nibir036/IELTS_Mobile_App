/// Where students can sign up, and how each one proves who they are
/// (the same list as the server's src/lib/countries.ts):
///
///   Bangladesh  mobile number, code by SMS
///   Gulf (GCC)  email address, code by email
///
/// SMS to the Gulf needs a sender name registered in each country, so the
/// Gulf countries use email instead.
class SignupCountry {
  const SignupCountry(this.code, this.name, this.dial, this.flag, {this.usesEmail = true});

  /// ISO 3166-1 alpha-2 ("BD", "SA" …), sent to the server as `country`.
  final String code;
  final String name;

  /// Calling code, for display ("+880").
  final String dial;

  /// Flag emoji.
  final String flag;

  /// Signs up with an email address; false = mobile number + SMS code.
  final bool usesEmail;
}

const List<SignupCountry> kSignupCountries = <SignupCountry>[
  SignupCountry('BD', 'Bangladesh', '+880', '🇧🇩', usesEmail: false),
  SignupCountry('BH', 'Bahrain', '+973', '🇧🇭'),
  SignupCountry('KW', 'Kuwait', '+965', '🇰🇼'),
  SignupCountry('OM', 'Oman', '+968', '🇴🇲'),
  SignupCountry('QA', 'Qatar', '+974', '🇶🇦'),
  SignupCountry('SA', 'Saudi Arabia', '+966', '🇸🇦'),
  SignupCountry('AE', 'United Arab Emirates', '+971', '🇦🇪'),
];

/// The country for [code]; Bangladesh when it is not one we serve.
SignupCountry signupCountryOf(String? code) {
  final c = (code ?? '').trim().toUpperCase();
  for (final x in kSignupCountries) {
    if (x.code == c) return x;
  }
  return kSignupCountries.first;
}
