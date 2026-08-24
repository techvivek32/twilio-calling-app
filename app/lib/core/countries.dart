/// A dialling country: ISO code, display name, and E.164 calling code.
class Country {
  const Country({
    required this.iso,
    required this.name,
    required this.dialCode,
    required this.flag,
  });

  final String iso;
  final String name;

  /// Digits only, without the leading `+`.
  final String dialCode;
  final String flag;

  String get label => '$flag  $name';
  String get plusCode => '+$dialCode';

  @override
  String toString() => '$iso ($plusCode)';
}

/// Countries offered by the dialler and the message composer.
///
/// Deliberately not exhaustive — it covers the widely used codes plus every
/// country Twilio commonly provisions numbers in. `Country.fromE164` still
/// resolves anything else by longest-prefix match where possible.
const List<Country> kCountries = [
  Country(iso: 'IN', name: 'India', dialCode: '91', flag: '🇮🇳'),
  Country(iso: 'US', name: 'United States', dialCode: '1', flag: '🇺🇸'),
  Country(iso: 'CA', name: 'Canada', dialCode: '1', flag: '🇨🇦'),
  Country(iso: 'GB', name: 'United Kingdom', dialCode: '44', flag: '🇬🇧'),
  Country(iso: 'AE', name: 'United Arab Emirates', dialCode: '971', flag: '🇦🇪'),
  Country(iso: 'AU', name: 'Australia', dialCode: '61', flag: '🇦🇺'),
  Country(iso: 'BD', name: 'Bangladesh', dialCode: '880', flag: '🇧🇩'),
  Country(iso: 'BR', name: 'Brazil', dialCode: '55', flag: '🇧🇷'),
  Country(iso: 'CN', name: 'China', dialCode: '86', flag: '🇨🇳'),
  Country(iso: 'DE', name: 'Germany', dialCode: '49', flag: '🇩🇪'),
  Country(iso: 'EG', name: 'Egypt', dialCode: '20', flag: '🇪🇬'),
  Country(iso: 'ES', name: 'Spain', dialCode: '34', flag: '🇪🇸'),
  Country(iso: 'FR', name: 'France', dialCode: '33', flag: '🇫🇷'),
  Country(iso: 'ID', name: 'Indonesia', dialCode: '62', flag: '🇮🇩'),
  Country(iso: 'IE', name: 'Ireland', dialCode: '353', flag: '🇮🇪'),
  Country(iso: 'IL', name: 'Israel', dialCode: '972', flag: '🇮🇱'),
  Country(iso: 'IT', name: 'Italy', dialCode: '39', flag: '🇮🇹'),
  Country(iso: 'JP', name: 'Japan', dialCode: '81', flag: '🇯🇵'),
  Country(iso: 'KE', name: 'Kenya', dialCode: '254', flag: '🇰🇪'),
  Country(iso: 'LK', name: 'Sri Lanka', dialCode: '94', flag: '🇱🇰'),
  Country(iso: 'MX', name: 'Mexico', dialCode: '52', flag: '🇲🇽'),
  Country(iso: 'MY', name: 'Malaysia', dialCode: '60', flag: '🇲🇾'),
  Country(iso: 'NG', name: 'Nigeria', dialCode: '234', flag: '🇳🇬'),
  Country(iso: 'NL', name: 'Netherlands', dialCode: '31', flag: '🇳🇱'),
  Country(iso: 'NP', name: 'Nepal', dialCode: '977', flag: '🇳🇵'),
  Country(iso: 'NZ', name: 'New Zealand', dialCode: '64', flag: '🇳🇿'),
  Country(iso: 'PH', name: 'Philippines', dialCode: '63', flag: '🇵🇭'),
  Country(iso: 'PK', name: 'Pakistan', dialCode: '92', flag: '🇵🇰'),
  Country(iso: 'PL', name: 'Poland', dialCode: '48', flag: '🇵🇱'),
  Country(iso: 'PT', name: 'Portugal', dialCode: '351', flag: '🇵🇹'),
  Country(iso: 'QA', name: 'Qatar', dialCode: '974', flag: '🇶🇦'),
  Country(iso: 'RU', name: 'Russia', dialCode: '7', flag: '🇷🇺'),
  Country(iso: 'SA', name: 'Saudi Arabia', dialCode: '966', flag: '🇸🇦'),
  Country(iso: 'SE', name: 'Sweden', dialCode: '46', flag: '🇸🇪'),
  Country(iso: 'SG', name: 'Singapore', dialCode: '65', flag: '🇸🇬'),
  Country(iso: 'TH', name: 'Thailand', dialCode: '66', flag: '🇹🇭'),
  Country(iso: 'TR', name: 'Türkiye', dialCode: '90', flag: '🇹🇷'),
  Country(iso: 'VN', name: 'Vietnam', dialCode: '84', flag: '🇻🇳'),
  Country(iso: 'ZA', name: 'South Africa', dialCode: '27', flag: '🇿🇦'),
];

/// The country used when nothing else is known.
const Country kDefaultCountry = Country(
  iso: 'IN',
  name: 'India',
  dialCode: '91',
  flag: '🇮🇳',
);

extension CountryLookup on Country {
  /// Finds a country by ISO code.
  static Country? byIso(String iso) {
    final upper = iso.toUpperCase();
    for (final country in kCountries) {
      if (country.iso == upper) return country;
    }
    return null;
  }

  /// Best guess of the country an E.164 number belongs to.
  ///
  /// Matches the longest dial code first, so `+971…` resolves to the UAE
  /// rather than to `+9…`.
  static Country? fromE164(String e164) {
    final digits = e164.replaceFirst('+', '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    Country? best;
    for (final country in kCountries) {
      if (!digits.startsWith(country.dialCode)) continue;
      if (best == null || country.dialCode.length > best.dialCode.length) {
        best = country;
      }
    }
    return best;
  }

  /// Splits an E.164 number into its country and the national part.
  static (Country, String) split(String e164) {
    final country = fromE164(e164) ?? kDefaultCountry;
    final digits = e164.replaceFirst('+', '').replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith(country.dialCode)
        ? digits.substring(country.dialCode.length)
        : digits;
    return (country, national);
  }
}

/// Joins a country and a national number into E.164, or '' when incomplete.
String toE164(Country country, String nationalDigits) {
  final digits = nationalDigits.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  // A leading trunk zero is national-only notation and must not be dialled.
  final trimmed = digits.startsWith('0') ? digits.replaceFirst('0', '') : digits;
  if (trimmed.isEmpty) return '';
  return '+${country.dialCode}$trimmed';
}

/// True when [value] is a plausible full international number.
bool looksLikeE164(String value) =>
    RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
