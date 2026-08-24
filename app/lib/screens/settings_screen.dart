import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/countries.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../widgets/country_picker.dart';
import 'permissions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.session});

  final AppSession? session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _viewKey = GlobalKey<AsyncViewState<HomeSummary>>();

  AppSession get _session => widget.session ?? AppSession.instance;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your email and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _session.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PermissionsScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BrandHeader(
          leading: IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            color: AppColors.textPrimary,
            padding: EdgeInsets.zero,
            tooltip: 'Sign out',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => showNotWired(context, 'Notification center'),
                icon: const Icon(Icons.notifications_none),
                color: AppColors.textPrimary,
              ),
              InitialsAvatar(name: _session.user?.name ?? 'User', size: 38),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<HomeSummary>(
            key: _viewKey,
            load: _session.loadHome,
            builder: (context, summary, reload) => RefreshIndicator(
              color: AppColors.primary,
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.lg,
                  AppSpace.lg,
                  AppSpace.xxl,
                ),
                children: [
                  Text(
                    'Connection Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  const Text(
                    'Your number and Twilio service, managed by your '
                    'administrator.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh, size: 22),
                    label: const Text('Refresh Connection'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _NumberCard(summary: summary),
                  const SizedBox(height: AppSpace.lg),
                  _MyPhoneCard(session: _session),
                  const SizedBox(height: AppSpace.lg),
                  _AccountCard(summary: summary, serverUrl: _session.serverUrl),
                  const SizedBox(height: AppSpace.lg),
                  _InfoCard(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'Voice calling',
                    subtitle: summary.number?.voice == true
                        ? 'Your number can place and receive calls.'
                        : 'Voice is not enabled on your number.',
                    ok: summary.number?.voice == true,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _InfoCard(
                    icon: Icons.outbox_outlined,
                    title: 'SMS messaging',
                    subtitle: summary.number?.sms == true
                        ? 'Your number can send and receive SMS.'
                        : 'SMS is not enabled on your number.',
                    ok: summary.number?.sms == true,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final number = summary.number;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: number == null
                      ? AppColors.textMuted
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.smartphone,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number?.formatted ?? 'No number assigned',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      number?.friendlyName.isNotEmpty == true
                          ? number!.friendlyName
                          : 'Primary Twilio Number',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              if (number == null)
                const StatusPill.danger('Unassigned')
              else if (summary.twilioConfigured)
                const StatusPill.success('Connected')
              else
                const StatusPill(
                  text: 'Pending',
                  background: AppColors.surfaceMuted,
                  foreground: AppColors.textSecondary,
                ),
            ],
          ),
          if (number == null) ...[
            const SizedBox(height: AppSpace.lg),
            const Text(
              'Ask your administrator to assign you a number in the admin '
              'panel. Calls and SMS unlock immediately afterwards.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.summary, required this.serverUrl});

  final HomeSummary summary;
  final String serverUrl;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Info',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.lg),
          _Row(label: 'Signed in as', value: summary.user.name),
          const SizedBox(height: AppSpace.md),
          _Row(label: 'Email', value: summary.user.email),
          const SizedBox(height: AppSpace.md),
          _Row(label: 'Server', value: serverUrl),
          const SizedBox(height: AppSpace.lg),
          const Text(
            'Twilio service',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: summary.twilioConfigured
                ? const StatusPill(
                    text: 'Configured by admin',
                    background: AppColors.successSoft,
                    foreground: AppColors.successText,
                    showDot: false,
                  )
                : const StatusPill(
                    text: 'Not configured',
                    background: AppColors.dangerSoft,
                    foreground: AppColors.danger,
                    showDot: false,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: ok ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                ok ? 'Active' : 'Off',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ok ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the user set the phone that click-to-call rings first.
///
/// Without it the dialler cannot place a call, so this is the one setting the
/// app must let a user fix themselves rather than waiting on an admin.
class _MyPhoneCard extends StatefulWidget {
  const _MyPhoneCard({required this.session});

  final AppSession session;

  @override
  State<_MyPhoneCard> createState() => _MyPhoneCardState();
}

class _MyPhoneCardState extends State<_MyPhoneCard> {
  late final TextEditingController _controller;
  late Country _country;
  bool _saving = false;
  String? _error;
  String? _saved;

  @override
  void initState() {
    super.initState();

    final stored = widget.session.user?.personalNumber ?? '';
    if (stored.isNotEmpty) {
      final (country, national) = CountryLookup.split(stored);
      _country = country;
      _controller = TextEditingController(text: national);
    } else {
      _country =
          CountryLookup.byIso(widget.session.dialCountryIso ?? '') ??
          kDefaultCountry;
      _controller = TextEditingController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final number = toE164(_country, _controller.text);

    if (number.isNotEmpty && !looksLikeE164(number)) {
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
      _saved = null;
    });

    try {
      await widget.session.setPersonalNumber(number);
      if (!mounted) return;
      setState(
        () => _saved = number.isEmpty
            ? 'Cleared. You cannot place calls until you set a number.'
            : 'Saved. Calls will ring $number first.',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.session.user?.personalNumber ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.smartphone_outlined,
                size: 22,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpace.sm),
              const Expanded(
                child: Text(
                  'Your phone',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              if (current.isEmpty)
                const StatusPill.danger('Required')
              else
                const StatusPill.success('Set'),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          const Text(
            'A call rings this phone first, then connects the person you '
            'dialled — showing your business number as the caller ID.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpace.md),
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
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    hintText: '98765 43210',
                  ),
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
          if (_saved != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _saved!,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.success,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_saving ? 'Saving…' : 'Save my phone'),
          ),
        ],
      ),
    );
  }
}
