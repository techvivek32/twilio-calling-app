import 'package:flutter/material.dart';

import '../core/countries.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/country_picker.dart';

/// One chosen recipient: a saved contact, or a number typed by hand.
class _Recipient {
  const _Recipient({required this.name, required this.phone});

  final String name;
  final String phone;

  String get label => name.isNotEmpty ? name : formatPhoneNumber(phone);
}

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({
    super.key,
    this.prefillNumber,
    this.prefillName,
    this.session,
  });

  final String? prefillNumber;
  final String? prefillName;
  final AppSession? session;

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _recipientController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<_Recipient> _recipients = [];

  List<Contact> _contacts = const [];
  bool _sending = false;
  Country _country = kDefaultCountry;

  static const int _smsLimit = 160;

  AppSession get _session => widget.session ?? AppSession.instance;

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(() => setState(() {}));

    final prefill = widget.prefillNumber;
    if (prefill != null && prefill.isNotEmpty) {
      _recipients.add(
        _Recipient(
          name: widget.prefillName ?? '',
          phone: normaliseE164(prefill),
        ),
      );
    }
    _loadContacts();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _session.loadContacts();
      if (mounted) setState(() => _contacts = contacts);
    } catch (_) {
      // Suggestions are optional — typing a raw number still works.
    }
  }

  List<Contact> get _suggestions {
    final query = _recipientController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final chosen = _recipients.map((r) => r.phone).toSet();
    return _contacts
        .where(
          (contact) =>
              !chosen.contains(contact.phone) &&
              (contact.name.toLowerCase().contains(query) ||
                  contact.phone.contains(query)),
        )
        .take(4)
        .toList();
  }

  void _addTyped() {
    final raw = _recipientController.text.trim();
    if (raw.isEmpty) return;

    final phone = raw.startsWith('+')
        ? normaliseE164(raw)
        : toE164(_country, raw);
    if (!looksLikeE164(phone)) {
      _toast(
        'That is not a complete ${_country.name} number. Check the digits and '
        'the country code.',
      );
      return;
    }
    _addRecipient(_Recipient(name: '', phone: phone));
  }

  void _addRecipient(_Recipient recipient) {
    if (_recipients.any((r) => r.phone == recipient.phone)) {
      _recipientController.clear();
      setState(() {});
      return;
    }
    setState(() {
      _recipients.add(recipient);
      _recipientController.clear();
    });
  }

  Future<void> _send() async {
    if (_sending) return;

    if (_recipients.isEmpty) {
      _toast('Add at least one recipient.');
      return;
    }
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      _toast('Write a message first.');
      return;
    }
    if (!_session.hasNumber) {
      _toast('No number is assigned to your account. Ask your administrator.');
      return;
    }

    setState(() => _sending = true);

    final failures = <String>[];
    String? warning;

    for (final recipient in _recipients) {
      try {
        final result = await _session.sendMessage(
          to: recipient.phone,
          body: body,
          contactName: recipient.name,
        );
        warning ??= result.warning;
      } catch (error) {
        failures.add('${recipient.label}: $error');
      }
    }

    if (!mounted) return;
    setState(() => _sending = false);

    if (failures.isNotEmpty) {
      _toast(failures.join('\n'));
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            warning ?? 'Sent to ${_recipients.length} recipient(s).',
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
    final length = _bodyController.text.length;
    final suggestions = _suggestions;
    final number = _session.number;

    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
            title: 'New Message',
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 26),
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              tooltip: 'Close',
            ),
            onBellTap: () => showNotWired(context, 'Notification center'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg,
                          vertical: AppSpace.md,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceMuted,
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sim_card_outlined,
                              size: 22,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpace.sm),
                            const CardLabel('Sending From'),
                            const Spacer(),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.md,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppSpace.radiusPill,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: number == null
                                            ? AppColors.danger
                                            : AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        number?.formatted ?? 'No number',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardLabel('To'),
                            const SizedBox(height: AppSpace.sm),
                            Row(
                              children: [
                                CountryCodeButton(
                                  country: _country,
                                  onChanged: (country) =>
                                      setState(() => _country = country),
                                  enabled: !_sending,
                                  dense: true,
                                ),
                                const SizedBox(width: AppSpace.sm),
                                const Expanded(
                                  child: Text(
                                    'Or type a full +… number',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.sm),
                            TextField(
                              controller: _recipientController,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _addTyped(),
                              textInputAction: TextInputAction.done,
                              enabled: !_sending,
                              decoration: InputDecoration(
                                hintText: 'Search contacts or enter number...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  onPressed: _addTyped,
                                  icon: const Icon(Icons.add),
                                  color: AppColors.primary,
                                  tooltip: 'Add recipient',
                                ),
                              ),
                            ),
                            if (suggestions.isNotEmpty) ...[
                              const SizedBox(height: AppSpace.sm),
                              for (final contact in suggestions)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: InitialsAvatar(
                                    name: contact.name,
                                    size: 36,
                                  ),
                                  title: Text(contact.name),
                                  subtitle: Text(contact.formattedPhone),
                                  onTap: () => _addRecipient(
                                    _Recipient(
                                      name: contact.name,
                                      phone: contact.phone,
                                    ),
                                  ),
                                ),
                            ],
                            if (_recipients.isNotEmpty) ...[
                              const SizedBox(height: AppSpace.md),
                              Wrap(
                                spacing: AppSpace.sm,
                                runSpacing: AppSpace.sm,
                                children: [
                                  for (final recipient in _recipients)
                                    _RecipientChip(
                                      label: recipient.label,
                                      onRemove: () => setState(
                                        () => _recipients.remove(recipient),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSpace.xl),
                            const CardLabel('Message'),
                            const SizedBox(height: AppSpace.sm),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppSpace.radiusField,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _bodyController,
                                    minLines: 4,
                                    maxLines: 8,
                                    enabled: !_sending,
                                    decoration: const InputDecoration(
                                      hintText: 'Type your message here...',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpace.sm,
                                      0,
                                      AppSpace.md,
                                      AppSpace.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        _ComposerIcon(
                                          icon: Icons.attach_file,
                                          onTap: () => showNotWired(
                                            context,
                                            'MMS attachments',
                                          ),
                                        ),
                                        _ComposerIcon(
                                          icon: Icons.notes,
                                          onTap: () => showNotWired(
                                            context,
                                            'Message templates',
                                          ),
                                        ),
                                        _ComposerIcon(
                                          icon: Icons.emoji_emotions_outlined,
                                          onTap: () => showNotWired(
                                            context,
                                            'The emoji picker',
                                          ),
                                        ),
                                        const Spacer(),
                                        Flexible(
                                          child: Text(
                                            '$length / $_smsLimit SMS limit',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: length > _smsLimit
                                                  ? AppColors.danger
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            const Divider(),
                            const SizedBox(height: AppSpace.lg),
                            FilledButton.icon(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send, size: 20),
                              label: Text(_sending ? 'Sending…' : 'Send SMS'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, AppSpace.sm, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpace.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialsAvatar(name: label, size: 28),
          const SizedBox(width: AppSpace.sm),
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 17,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      color: AppColors.textSecondary,
      visualDensity: VisualDensity.compact,
    );
  }
}
