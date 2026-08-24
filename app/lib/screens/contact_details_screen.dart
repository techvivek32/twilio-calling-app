import 'package:flutter/material.dart';

import '../core/call_launcher.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'new_message_screen.dart';

class ContactDetailsScreen extends StatelessWidget {
  const ContactDetailsScreen({
    super.key,
    required this.contact,
    this.session,
  });

  final Contact contact;
  final AppSession? session;

  AppSession get _session => session ?? AppSession.instance;

  Future<void> _call(BuildContext context) => startCall(
    context,
    number: contact.phone,
    contactName: contact.name,
    displayName: contact.name,
    role: contact.role,
    session: session,
  );

  void _message(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewMessageScreen(
          prefillNumber: contact.phone,
          prefillName: contact.name,
        ),
      ),
    );
  }

  /// Calls with this contact, pulled from the shared history endpoint.
  Future<List<CallRecord>> _loadHistory() async {
    final calls = await _session.loadCalls();
    final digits = contact.phone.replaceAll(RegExp(r'\D'), '');
    final tail = digits.length > 7 ? digits.substring(digits.length - 7) : digits;

    return calls
        .where(
          (call) => call.peerNumber.replaceAll(RegExp(r'\D'), '').endsWith(tail),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Contact Details',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              children: [
                InitialsAvatar(name: contact.name, size: 104),
                const SizedBox(height: AppSpace.lg),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    contact.name,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  contact.formattedPhone,
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (contact.role.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    contact.role,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _call(context),
                        icon: const Icon(Icons.phone_rounded, size: 20),
                        label: const Text('Call'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _message(context),
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            'Recent History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 280,
            child: AsyncView<List<CallRecord>>(
              load: _loadHistory,
              builder: (context, calls, reload) {
                if (calls.isEmpty) {
                  return const AppCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
                      child: Center(
                        child: Text(
                          'No calls with this contact yet.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return AppCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: calls.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) =>
                        _HistoryRow(call: calls[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.call});

  final CallRecord call;

  @override
  Widget build(BuildContext context) {
    final missed = call.displayDirection == CallDirection.missed;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: missed ? AppColors.dangerSoft : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              call.displayDirection.icon,
              size: 20,
              color: missed ? AppColors.danger : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${call.displayDirection.label} Call',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: missed ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  missed
                      ? call.timeLabel
                      : '${call.timeLabel} • ${call.durationLabel}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          missed
              ? const StatusPill.danger('Missed')
              : const StatusPill.success('Connected'),
        ],
      ),
    );
  }
}
