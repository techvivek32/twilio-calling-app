import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/countries.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/country_picker.dart';
import 'active_call_screen.dart';

/// Groups the national part of a number for readability while it is typed.
///
/// Deliberately country-agnostic: the dialled country comes from the picker,
/// so this only spaces the digits rather than imposing a US pattern.
String formatNationalDigits(String digits) {
  if (digits.isEmpty) return '';
  final groups = <String>[];
  for (var i = 0; i < digits.length; i += 5) {
    groups.add(digits.substring(i, (i + 5).clamp(0, digits.length)));
  }
  return groups.join(' ');
}

/// What the dialler shows above the keypad.
String formatDialedNumber(Country country, String digits) {
  if (digits.isEmpty) return '';
  return '${country.plusCode} ${formatNationalDigits(digits)}'.trimRight();
}

class DialerScreen extends StatefulWidget {
  const DialerScreen({
    super.key,
    this.onShowHistory,
    this.session,
    this.initialNumber = '',
  });

  final VoidCallback? onShowHistory;
  final AppSession? session;

  /// Prefilled number. A leading `+` is split into its country and national
  /// part; anything else is treated as national digits.
  final String initialNumber;

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _digits = '';
  List<Contact> _contacts = const [];
  bool _placing = false;
  Country _country = kDefaultCountry;

  AppSession get _session => widget.session ?? AppSession.instance;

  @override
  void initState() {
    super.initState();

    if (widget.initialNumber.startsWith('+')) {
      final (country, national) = CountryLookup.split(widget.initialNumber);
      _country = country;
      _digits = national;
    } else {
      _country = _initialCountry();
      _digits = digitsOnly(widget.initialNumber);
    }

    _loadContacts();
  }

  /// Last country the user picked, else the country of their own Twilio
  /// number, else the default.
  Country _initialCountry() {
    final saved = _session.dialCountryIso;
    if (saved != null) {
      final match = CountryLookup.byIso(saved);
      if (match != null) return match;
    }
    final own = _session.number?.phoneNumber;
    if (own != null) {
      final match = CountryLookup.fromE164(own);
      if (match != null) return match;
    }
    return kDefaultCountry;
  }

  void _selectCountry(Country country) {
    setState(() => _country = country);
    _session.setDialCountry(country.iso);
  }

  /// The full international number the keypad currently represents.
  String get _e164 => toE164(_country, _digits);

  Future<void> _loadContacts() async {
    try {
      final contacts = await _session.loadContacts();
      if (mounted) setState(() => _contacts = contacts);
    } catch (_) {
      // Contact matching is a nicety; the keypad still works without it.
    }
  }

  Contact? get _match {
    if (_digits.length < 7) return null;
    final tail = _digits.substring(_digits.length - 7);
    for (final contact in _contacts) {
      if (digitsOnly(contact.phone).endsWith(tail)) return contact;
    }
    return null;
  }

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_digits.length < 15) _digits += key;
    });
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _clear() {
    if (_digits.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _digits = '');
  }

  Future<void> _addContact() async {
    if (_digits.isEmpty) return;
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add to contacts'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: formatDialedNumber(_country, _digits),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();

    if (name == null || name.isEmpty || !mounted) return;

    try {
      await _session.addContact(name: name, phone: _e164);
      await _loadContacts();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Saved $name to contacts.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _call() async {
    if (_digits.isEmpty || _placing) return;

    if (!_session.hasNumber) {
      _toast(
        'No phone number is assigned to your account. Ask your administrator.',
      );
      return;
    }

    final target = _e164;
    if (!looksLikeE164(target)) {
      _toast(
        'That is not a complete ${_country.name} number. Check the digits and '
        'the country code.',
      );
      return;
    }

    final match = _match;
    final name = match?.name ?? formatDialedNumber(_country, _digits);

    setState(() => _placing = true);
    String? callSid;
    String? warning;

    try {
      callSid = await _session.placeCall(
        to: target,
        contactName: match?.name ?? '',
      );
    } catch (error) {
      warning = error.toString();
    } finally {
      if (mounted) setState(() => _placing = false);
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          name: name,
          phone: formatDialedNumber(_country, _digits),
          rawNumber: target,
          contactName: match?.name ?? '',
          callSid: callSid,
          warning: warning,
          session: widget.session,
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    final formatted = formatDialedNumber(_country, _digits);
    final number = _session.number;

    return Column(
      children: [
        BrandHeader(
          leading: Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: InitialsAvatar(
              name: _session.user?.name ?? 'User',
              size: 40,
              showPersonIcon: true,
            ),
          ),
          onBellTap: () => showNotWired(context, 'Notification center'),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xl,
                      vertical: AppSpace.lg,
                    ),
                    child: Column(
                      children: [
                        if (match != null) ...[
                          const Text(
                            'Matching Contact',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            match.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ] else
                          const SizedBox(height: 46),
                        const SizedBox(height: AppSpace.md),
                        CountryCodeButton(
                          country: _country,
                          onChanged: _selectCountry,
                          enabled: !_placing,
                        ),
                        const SizedBox(height: AppSpace.md),
                        Row(
                          children: [
                            const SizedBox(width: 34),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  formatted.isEmpty
                                      ? 'Enter a number'
                                      : formatted,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    color: formatted.isEmpty
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 34,
                              child: _digits.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: _backspace,
                                      onLongPress: _clear,
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.backspace_outlined,
                                      ),
                                      color: AppColors.textSecondary,
                                      iconSize: 24,
                                      tooltip: 'Delete',
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.md),
                        TextButton.icon(
                          onPressed: match == null && _digits.isNotEmpty
                              ? _addContact
                              : null,
                          icon: const Icon(Icons.person_add_alt, size: 20),
                          label: const Text('Add to Contacts'),
                        ),
                        const SizedBox(height: AppSpace.md),
                        _Keypad(onPressed: _press),
                        const SizedBox(height: AppSpace.xl),
                        CircleActionButton(
                          icon: _placing ? Icons.hourglass_top : Icons.phone_rounded,
                          size: 78,
                          iconSize: 34,
                          background: AppColors.success,
                          foreground: Colors.white,
                          borderColor: null,
                          glowColor: AppColors.success,
                          onTap: _placing ? null : _call,
                          tooltip: 'Call',
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md,
                            vertical: AppSpace.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(
                              AppSpace.radiusPill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: number == null
                                      ? AppColors.danger
                                      : AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  number == null
                                      ? 'No number assigned to this account'
                                      : 'Calling via Twilio: ${number.formatted}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        if (widget.onShowHistory != null)
                          TextButton.icon(
                            onPressed: widget.onShowHistory,
                            icon: const Icon(Icons.history, size: 20),
                            label: const Text('Call History'),
                          ),
                        const SizedBox(height: AppSpace.sm),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onPressed});

  final ValueChanged<String> onPressed;

  static const List<List<List<String>>> _rows = [
    [
      ['1', ''],
      ['2', 'ABC'],
      ['3', 'DEF'],
    ],
    [
      ['4', 'GHI'],
      ['5', 'JKL'],
      ['6', 'MNO'],
    ],
    [
      ['7', 'PQRS'],
      ['8', 'TUV'],
      ['9', 'WXYZ'],
    ],
    [
      ['*', ''],
      ['0', '+'],
      ['#', ''],
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final key in row)
                  _KeypadKey(
                    digit: key[0],
                    letters: key[1],
                    onTap: () => onPressed(key[0]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    required this.digit,
    required this.letters,
    required this.onTap,
  });

  final String digit;
  final String letters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Material(
        color: AppColors.surfaceMuted,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                digit,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
