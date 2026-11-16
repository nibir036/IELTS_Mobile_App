// Where students can sign up, and how each one proves who they are.
//
//   Bangladesh  -> mobile number, code by SMS (Alpha SMS)
//   GCC         -> email address, code by email (Brevo)
//
// SMS to the Gulf needs a sender name registered in each country, so the
// Gulf countries use email instead. bKash works in Bangladesh only, so for
// now Gulf students buy Pro in the app (Google Play), not on the website.

export type SignupChannel = 'phone' | 'email';

export interface Country {
  /** ISO 3166-1 alpha-2, stored on users.country. */
  code: string;
  name: string;
  /** Calling code, for display. */
  dial: string;
  channel: SignupChannel;
  /** bKash on the website (Bangladesh only). */
  webPayments: boolean;
}

export const COUNTRIES: readonly Country[] = [
  { code: 'BD', name: 'Bangladesh', dial: '+880', channel: 'phone', webPayments: true },
  { code: 'BH', name: 'Bahrain', dial: '+973', channel: 'email', webPayments: false },
  { code: 'KW', name: 'Kuwait', dial: '+965', channel: 'email', webPayments: false },
  { code: 'OM', name: 'Oman', dial: '+968', channel: 'email', webPayments: false },
  { code: 'QA', name: 'Qatar', dial: '+974', channel: 'email', webPayments: false },
  { code: 'SA', name: 'Saudi Arabia', dial: '+966', channel: 'email', webPayments: false },
  { code: 'AE', name: 'United Arab Emirates', dial: '+971', channel: 'email', webPayments: false },
];

/** The country for a code ("sa", "SA"); undefined when it is not one we serve. */
export function countryOf(code: unknown): Country | undefined {
  const c = String(code ?? '').trim().toUpperCase();
  return COUNTRIES.find((x) => x.code === c);
}

/** Accounts from before countries existed are Bangladeshi (phone sign-up). */
export function countryOfUser(u: { country?: string | null }): Country {
  return countryOf(u.country) ?? COUNTRIES[0];
}
