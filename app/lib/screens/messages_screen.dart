import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'conversation_screen.dart';
import 'new_message_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.session});

  final AppSession? session;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  AppSession get _session => widget.session ?? AppSession.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _filter(List<Conversation> conversations) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return conversations;
    return conversations
        .where(
          (c) =>
              c.displayName.toLowerCase().contains(query) ||
              (c.last?.body.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Conversation>>(
      load: _session.loadConversations,
      builder: (context, conversations, reload) {
        final filtered = _filter(conversations);

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
                  bellHasBadge: conversations.isNotEmpty,
                  onBellTap: () =>
                      showNotWired(context, 'Notification center'),
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
                        'Messages',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Search messages and contacts...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: reload,
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              _EmptyMessages(),
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
                            itemBuilder: (context, index) => _ConversationTile(
                              conversation: filtered[index],
                              onReturn: reload,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: AppSpace.xl,
              bottom: AppSpace.xl,
              child: CircleActionButton(
                icon: Icons.edit_outlined,
                size: 60,
                iconSize: 26,
                background: AppColors.primary,
                foreground: Colors.white,
                borderColor: null,
                glowColor: AppColors.primary,
                tooltip: 'New message',
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NewMessageScreen(),
                    ),
                  );
                  await reload();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onReturn,
  });

  final Conversation conversation;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final last = conversation.last;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(conversation: conversation),
          ),
        );
        await onReturn();
      },
      child: Row(
        children: [
          InitialsAvatar(name: conversation.displayName, size: 52),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      last?.timeLabel ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  last?.body ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: (last?.failed ?? false)
                        ? AppColors.danger
                        : AppColors.textSecondary,
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

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 44,
            color: AppColors.textMuted,
          ),
          SizedBox(height: AppSpace.md),
          Text(
            'No conversations yet.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
