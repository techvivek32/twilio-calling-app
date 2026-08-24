import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/countries.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'country_picker.dart';

/// Makes sure the user has told us which phone to ring before a call.
///
/// Click-to-call needs a real handset to bridge to. Rather than refusing the
/// call and pointing at another screen, this asks for the number where the
/// user already is, then lets the call continue.
///
/// Returns true when a number is set — either already, or just now.
Future<bool> ensurePersonalNumber(
  BuildContext context,
  AppSession session,
) async {
  if ((session.user?.personalNumber ?? '').isNotEmpty) return true;

  // An admin may have set it on the user's page since this device signed in,
  // so refresh before asking for something already on file.
  try {
    await session.loadHome();
  } catch (_) {
    // Offline or the server is down; the prompt below still works.
  }
  if ((session.user?.personalNumber ?? '').isNotEmpty) return true;
  if (!context.mounted) return false;

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PersonalNumberDialog(session: session),
  );
  return saved ?? false;
}

class _PersonalNumberDialog extends StatefulWidget {
  const _PersonalNumberDialog({required this.session});

  final AppSession session;

  @override
  State<_PersonalNumberDialog> createState() => _PersonalNumberDialogState();
}

class _PersonalNumberDialogState extends State<_PersonalNumberDialog> {
  final _controller = TextEditingController();

  /// Default to the country they have been dialling. Guessing from the
  /// assigned Twilio number is actively wrong when the business number is
  /// foreign to the user — a Canadian line held by someone in India.
  late Country _country =
      CountryLookup.byIso(widget.session.dialCountryIso ?? '') ??
      kDefaultCountry;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final number = toE164(_country, _controller.text);
    if (!looksLikeE164(number)) {
      setState(
        () => _error =
            'That is not a complete ${_country.name} number. Check the digits '
            'and the country code.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.session.setPersonalNumber(number);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Which phone should ring?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A call rings your phone first, then connects the person you '
            'dialled. Enter the phone you are holding.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              CountryCodeButton(
                country: _country,
                onChanged: (country) => setState(() => _country = country),
                enabled: !_saving,
                dense: true,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(hintText: '98765 43210'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save and call'),
        ),
      ],
    );
  }
}
