import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'contacts_screen.dart';
import 'new_message_screen.dart';
import 'shell_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenDialer,
    required this.onOpenTab,
    this.session,
  });

  final VoidCallback onOpenDialer;
  final ValueChanged<ShellTab> onOpenTab;
  final AppSession? session;

  AppSession get _session => session ?? AppSession.instance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BrandHeader(
          leading: Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: InitialsAvatar(
              name: _session.user?.name ?? 'User',
              size: 40,
            ),
          ),
          bellHasBadge: true,
          onBellTap: () => showNotWired(context, 'Notification center'),
        ),
        Expanded(
          child: AsyncView<HomeSummary>(
            load: _session.loadHome,
            builder: (context, summary, reload) => RefreshIndicator(
              color: AppColors.primary,
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.xl,
                  AppSpace.lg,
                  AppSpace.xxl,
                ),
                children: [
                  Text(
                    '${_greeting()}, ${summary.user.firstName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  const Text(
                    "Here's your communication summary for today.",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _PrimaryNumberCard(summary: summary),
                  const SizedBox(height: AppSpace.lg),
                  _TodaysCallsCard(
                    summary: summary,
                    onTap: () => onOpenTab(ShellTab.calls),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _MessagesCard(
                    summary: summary,
                    onTap: () => onOpenTab(ShellTab.messages),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _QuickActionsCard(
                    onDialer: onOpenDialer,
                    onNewMessage: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NewMessageScreen(),
                        ),
                      );
                      await reload();
                    },
                    onContacts: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ContactsScreen()),
                    ),
                    onSettings: () => onOpenTab(ShellTab.settings),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _RecentActivityCard(items: summary.activity),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _PrimaryNumberCard extends StatelessWidget {
  const _PrimaryNumberCard({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final number = summary.number;
    final connected = number != null && summary.twilioConfigured;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: CardLabel('Primary Number')),
              if (connected)
                const StatusPill.success('Connected')
              else if (number != null)
                const StatusPill(
                  text: 'Twilio not set up',
                  background: AppColors.surfaceMuted,
                  foreground: AppColors.textSecondary,
                )
              else
                const StatusPill.danger('Not assigned'),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              number?.formatted ?? 'No number yet',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: number == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpace.radiusField),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.router_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    number == null
                        ? 'Ask your admin for a number'
                        : _capabilityLabel(number),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                const Flexible(
                  child: Text(
                    'Live',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _capabilityLabel(AssignedNumber number) {
    final parts = <String>[
      if (number.voice) 'Voice',
      if (number.sms) 'SMS',
      if (number.mms) 'MMS',
    ];
    if (parts.isEmpty) return 'No capabilities';
    return '${parts.join(' & ')} Active';
  }
}

class _TodaysCallsCard extends StatelessWidget {
  const _TodaysCallsCard({required this.summary, required this.onTap});

  final HomeSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: CardLabel("Today's Calls")),
              Icon(Icons.phone_rounded, size: 22, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '${summary.callsToday}',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpace.md),
          const Divider(),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.xl,
            runSpacing: AppSpace.sm,
            children: [
              _CallStatChip(
                icon: Icons.call_missed,
                color: AppColors.danger,
                label: '${summary.missedToday} Missed',
              ),
              _CallStatChip(
                icon: Icons.call_received,
                color: AppColors.success,
                label: '${summary.incomingToday} Incoming',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallStatChip extends StatelessWidget {
  const _CallStatChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MessagesCard extends StatelessWidget {
  const _MessagesCard({required this.summary, required this.onTap});

  final HomeSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: CardLabel('Messages')),
              Icon(
                Icons.chat_bubble_outline,
                size: 22,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary.unreadMessages}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              const Text(
                'Received',
                style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (summary.hasLatestMessage) ...[
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppSpace.radiusField),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          formatPhoneNumber(summary.latestSender),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.latestBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onDialer,
    required this.onNewMessage,
    required this.onContacts,
    required this.onSettings,
  });

  final VoidCallback onDialer;
  final VoidCallback onNewMessage;
  final VoidCallback onContacts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardLabel('Quick Actions'),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.dialpad,
                  label: 'Dialer',
                  primary: true,
                  onTap: onDialer,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _QuickAction(
                  icon: Icons.edit_outlined,
                  label: 'New Message',
                  onTap: onNewMessage,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.contact_page_outlined,
                  label: 'Contacts',
                  onTap: onContacts,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _QuickAction(
                  icon: Icons.settings_outlined,
                  label: 'Twilio Settings',
                  onTap: onSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.textPrimary;

    return Material(
      color: primary ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpace.radiusField),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpace.radiusField),
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpace.radiusField),
            border: Border.all(
              color: primary ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: primary ? Colors.white : AppColors.primary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardLabel('Recent Activity'),
          const SizedBox(height: AppSpace.md),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
              child: Text(
                'Nothing yet. Calls and messages show up here.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final item in items) ...[
              _ActivityRow(item: item),
              if (item != items.last) const SizedBox(height: AppSpace.lg),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final accent = item.isAlert ? AppColors.danger : AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.isAlert ? AppColors.dangerSoft : AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, size: 20, color: accent),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: item.isAlert
                      ? AppColors.danger
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(
          item.timeLabel,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
