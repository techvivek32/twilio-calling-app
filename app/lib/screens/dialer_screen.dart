import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'active_call_screen.dart';

/// Formats a raw digit string into +1 (XXX) XXX-XXXX as it is typed.
String formatDialedNumber(String digits) {
  if (digits.isEmpty) return '';
  // Longer than a US number (1 + 10 digits): show it raw rather than truncate.
  if (digits.length > 11) return '+$digits';

  final buffer = StringBuffer();
  var rest = digits;

  if (rest.startsWith('1') && rest.length > 1) {
    buffer.write('+1 ');
    rest = rest.substring(1);
  } else if (rest == '1') {
    return '+1';
  }

  if (rest.isEmpty) return buffer.toString().trimRight();

  final area = rest.substring(0, rest.length.clamp(0, 3));
  if (rest.length <= 3) {
    buffer.write('($area');
    return buffer.toString();
  }
  buffer.write('($area) ');

  final middle = rest.substring(3, rest.length.clamp(3, 6));
  if (rest.length <= 6) {
    buffer.write(middle);
    return buffer.toString();
  }
  buffer.write('$middle-');
  buffer.write(rest.substring(6, rest.length.clamp(6, 10)));
  return buffer.toString();
}

class DialerScreen extends StatefulWidget {
  const DialerScreen({
    super.key,
    this.onShowHistory,
    this.session,
    this.initialDigits = '',
  });

  final VoidCallback? onShowHistory;
  final AppSession? session;
  final String initialDigits;

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  late String _digits = widget.initialDigits;
  List<Contact> _contacts = const [];
  bool _placing = false;

  AppSession get _session => widget.session ?? AppSession.instance;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

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
            hintText: formatDialedNumber(_digits),
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
      await _session.addContact(name: name, phone: _digits);
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

    final match = _match;
    final name = match?.name ?? formatDialedNumber(_digits);

    setState(() => _placing = true);
    String? callSid;
    String? warning;

    try {
      callSid = await _session.placeCall(
        to: _digits,
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
          phone: formatDialedNumber(_digits),
          rawNumber: _digits,
          contactName: match?.name ?? '',
          callSid: callSid,
          warning: warning,
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
    final formatted = formatDialedNumber(_digits);
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
