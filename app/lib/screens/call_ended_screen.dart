import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'active_call_screen.dart';
import 'new_message_screen.dart';

class CallEndedScreen extends StatelessWidget {
  const CallEndedScreen({
    super.key,
    required this.name,
    required this.durationLabel,
    this.phone = '',
    this.rawNumber,
    this.contactName = '',
    this.role,
    this.session,
  });

  final String name;
  final String durationLabel;
  final String phone;
  final String? rawNumber;
  final String contactName;
  final String? role;
  final AppSession? session;

  AppSession get _session => session ?? AppSession.instance;

  String get _dialTarget => rawNumber ?? phone;

  Future<void> _callAgain(BuildContext context) async {
    String? callSid;
    String? warning;

    try {
      callSid = await _session.placeCall(
        to: _dialTarget,
        contactName: contactName,
      );
    } catch (error) {
      warning = error.toString();
    }

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          name: name,
          phone: phone.isEmpty ? name : phone,
          rawNumber: rawNumber,
          contactName: contactName,
          role: role,
          callSid: callSid,
          warning: warning,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.xxl,
                AppSpace.xl,
                AppSpace.xl,
              ),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: AppColors.dangerSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_end,
                      size: 36,
                      color: AppColors.dangerDeep,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Text(
                    'Call Ended',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: Column(
                      children: [
                        InitialsAvatar(name: name, size: 96),
                        const SizedBox(height: AppSpace.lg),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            name,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (role != null && role!.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            role!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.xl),
                        const Divider(),
                        const SizedBox(height: AppSpace.xl),
                        Row(
                          children: [
                            Expanded(
                              child: _CallStat(
                                icon: Icons.access_time,
                                label: 'Duration',
                                value: durationLabel,
                              ),
                            ),
                            Expanded(
                              child: _CallStat(
                                icon: Icons.calendar_today_outlined,
                                label: 'Time',
                                value: formatTimestamp(DateTime.now()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Row(
                    children: [
                      Expanded(
                        child: _EndedAction(
                          icon: Icons.phone_rounded,
                          label: 'Call Again',
                          onTap: () => _callAgain(context),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: _EndedAction(
                          icon: Icons.chat_bubble_outline,
                          label: 'Send SMS',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NewMessageScreen(
                                prefillNumber: _dialTarget,
                                prefillName: contactName,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: _EndedAction(
                          icon: Icons.person_add_alt,
                          label: 'Add Contact',
                          onTap: () => _addContact(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text(
                      'RETURN TO HISTORY',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact(BuildContext context) async {
    if (_dialTarget.isEmpty) return;
    final controller = TextEditingController(text: contactName);

    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add to contacts'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (chosen == null || chosen.isEmpty || !context.mounted) return;

    try {
      await _session.addContact(name: chosen, phone: _dialTarget);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Saved $chosen to contacts.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _CallStat extends StatelessWidget {
  const _CallStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.textPrimary),
        const SizedBox(height: AppSpace.sm),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EndedAction extends StatelessWidget {
  const _EndedAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.lg, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(height: AppSpace.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
