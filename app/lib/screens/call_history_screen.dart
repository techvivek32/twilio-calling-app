import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import '../core/call_launcher.dart';
import 'contact_details_screen.dart';
import 'new_message_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key, this.onOpenDialer, this.session});

  final VoidCallback? onOpenDialer;
  final AppSession? session;

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _searchController = TextEditingController();
  final _viewKey = GlobalKey<AsyncViewState<List<CallRecord>>>();
  int _tabIndex = 0;
  String _query = '';

  static const List<String> _tabs = ['All', 'Missed', 'Incoming', 'Outgoing'];

  AppSession get _session => widget.session ?? AppSession.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CallRecord> _filter(List<CallRecord> calls) {
    final query = _query.trim().toLowerCase();

    return calls.where((call) {
      final matchesTab = switch (_tabIndex) {
        1 => call.displayDirection == CallDirection.missed,
        2 => call.displayDirection == CallDirection.incoming,
        3 => call.displayDirection == CallDirection.outgoing,
        _ => true,
      };
      if (!matchesTab) return false;
      if (query.isEmpty) return true;
      return call.displayName.toLowerCase().contains(query) ||
          call.peerNumber.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            BrandHeader(
              leading: Padding(
                padding: const EdgeInsets.only(right: AppSpace.xs),
                child: InitialsAvatar(
                  name: _session.user?.name ?? 'User',
                  size: 40,
                ),
              ),
              onBellTap: () => showNotWired(context, 'Notification center'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.xl,
                AppSpace.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Call History',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search calls, contacts, numbers...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _FilterTabs(
                    tabs: _tabs,
                    current: _tabIndex,
                    onSelect: (index) => setState(() => _tabIndex = index),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncView<List<CallRecord>>(
                key: _viewKey,
                load: _session.loadCalls,
                builder: (context, calls, reload) {
                  final filtered = _filter(calls);

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: reload,
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              _EmptyState(),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.lg,
                              AppSpace.lg,
                              AppSpace.lg,
                              96,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpace.md),
                            itemBuilder: (context, index) => _CallLogTile(
                              session: _session,
                              call: filtered[index],
                              onChanged: reload,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
        if (widget.onOpenDialer != null)
          Positioned(
            right: AppSpace.xl,
            bottom: AppSpace.xl,
            child: CircleActionButton(
              icon: Icons.dialpad,
              size: 60,
              iconSize: 26,
              background: AppColors.primary,
              foreground: Colors.white,
              borderColor: null,
              glowColor: AppColors.primary,
              onTap: widget.onOpenDialer,
              tooltip: 'Open dialer',
            ),
          ),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.tabs,
    required this.current,
    required this.onSelect,
  });

  final List<String> tabs;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: current == i
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: current == i
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: current == i
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CallLogTile extends StatelessWidget {
  const _CallLogTile({
    required this.call,
    required this.onChanged,
    this.session,
  });

  final CallRecord call;
  final Future<void> Function() onChanged;
  final AppSession? session;

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactDetailsScreen(
          contact: Contact(
            id: call.id,
            name: call.displayName,
            phone: call.peerNumber,
            numberLabel: call.isKnownContact ? 'Work' : 'Unknown',
          ),
          session: session,
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context) async {
    await startCall(
      context,
      number: call.peerNumber,
      contactName: call.contactName,
      displayName: call.displayName,
      session: session,
    );
    await onChanged();
  }

  Future<void> _message(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewMessageScreen(prefillNumber: call.peerNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missed = call.displayDirection == CallDirection.missed;

    return AppCard(
      onTap: () => _openDetails(context),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.md,
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: call.displayName,
            size: 52,
            showPersonIcon: !call.isKnownContact,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: missed ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      call.displayDirection.icon,
                      size: 16,
                      color: missed
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${call.displayDirection.label} • ${call.timeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: missed
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          CircleActionButton(
            icon: Icons.chat_bubble_outline,
            size: 44,
            iconSize: 20,
            foreground: AppColors.textSecondary,
            onTap: () => _message(context),
            tooltip: 'Message',
          ),
          const SizedBox(width: AppSpace.sm),
          CircleActionButton(
            icon: Icons.phone_rounded,
            size: 44,
            iconSize: 20,
            background: missed ? AppColors.primary : AppColors.surface,
            foreground: missed ? Colors.white : AppColors.textSecondary,
            borderColor: missed ? null : AppColors.border,
            onTap: () => _call(context),
            tooltip: 'Call back',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_disabled_outlined,
            size: 44,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSpace.md),
          Text(
            'No calls match this filter.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Exposed so the dialer can reuse the same formatter in tests.
String describeCall(CallRecord call) =>
    '${call.displayName} · ${formatPhoneNumber(call.peerNumber)}';
