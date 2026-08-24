import 'dart:async';

import 'package:flutter/material.dart';

import '../core/call_launcher.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'message_details_screen.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversation,
    this.session,
  });

  final Conversation conversation;
  final AppSession? session;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  late List<ChatMessage> _messages = [...widget.conversation.messages];
  bool _sending = false;
  Timer? _poll;

  AppSession get _session => widget.session ?? AppSession.instance;

  @override
  void initState() {
    super.initState();

    // Opening the thread is what makes it read.
    unawaited(_markRead());

    // A reply arrives by SMS, not through this app, so the only way to see it
    // while the thread is open is to ask the server for it.
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await _session.markThreadRead(widget.conversation.peer);
    } catch (_) {
      // A failed read receipt must never interrupt reading the thread.
    }
  }

  /// Pulls the thread again and appends anything new.
  Future<void> _refresh() async {
    if (_sending) return;

    try {
      final thread = await _session.loadThread(widget.conversation.peer);
      if (!mounted || thread == null) return;
      if (thread.messages.length <= _messages.length) return;

      final atBottom =
          !_scrollController.hasClients ||
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 40;

      setState(() => _messages = [...thread.messages]);
      unawaited(_markRead());

      // Only follow the new message if the user was already at the bottom;
      // yanking the view while they read older messages is worse than not.
      if (atBottom) _scrollToEnd();
    } catch (_) {
      // Offline or a blip: the next tick tries again.
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final result = await _session.sendMessage(
        to: widget.conversation.peer,
        body: text,
        contactName: widget.conversation.contactName,
      );

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, result.message];
        _composer.clear();
      });
      _scrollToEnd();

      if (result.warning != null) _toast(result.warning!);
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resend(ChatMessage message) async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final result = await _session.sendMessage(
        to: widget.conversation.peer,
        body: message.body,
        contactName: widget.conversation.contactName,
      );
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final existing in _messages)
            if (existing.id == message.id) result.message else existing,
        ];
      });
      _toast(result.warning ?? 'Message resent.');
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 40,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          padding: EdgeInsets.zero,
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            InitialsAvatar(name: conversation.displayName, size: 42),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    conversation.formattedPeer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _callPeer(context),
            icon: const Icon(Icons.phone_rounded),
            color: AppColors.primary,
            tooltip: 'Call',
          ),
          const SizedBox(width: AppSpace.xs),
        ],
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.xl,
              ),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return const _DayDivider(label: 'Conversation');
                final message = _messages[index - 1];
                return _MessageBubble(
                  message: message,
                  onRetry: () => _resend(message),
                  onOpenDetails: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MessageDetailsScreen(
                        message: message,
                        peerNumber: conversation.peer,
                        peerName: conversation.displayName,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _Composer(
            controller: _composer,
            onSend: _send,
            sending: _sending,
          ),
        ],
      ),
    );
  }

  Future<void> _callPeer(BuildContext context) => startCall(
    context,
    number: widget.conversation.peer,
    contactName: widget.conversation.contactName,
    displayName: widget.conversation.displayName,
    session: widget.session,
  );
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.lg),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSpace.radiusPill),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onRetry,
    required this.onOpenDetails,
  });

  final ChatMessage message;
  final VoidCallback onRetry;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final fromMe = message.fromMe;
    final failed = message.failed;
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: fromMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: fromMe ? onOpenDetails : null,
            child: Container(
              constraints: BoxConstraints(maxWidth: width * 0.78),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.md,
              ),
              decoration: BoxDecoration(
                color: fromMe ? AppColors.primary : AppColors.surface,
                border: fromMe ? null : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppSpace.radiusCard),
                  topRight: const Radius.circular(AppSpace.radiusCard),
                  bottomLeft: Radius.circular(fromMe ? AppSpace.radiusCard : 4),
                  bottomRight: Radius.circular(fromMe ? 4 : AppSpace.radiusCard),
                ),
              ),
              child: Text(
                message.body,
                style: TextStyle(
                  fontSize: 16.5,
                  height: 1.4,
                  color: fromMe ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: fromMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  fromMe
                      ? '${message.timeLabel} • ${message.status.label}'
                      : message.timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: failed ? FontWeight.w700 : FontWeight.w400,
                    color: failed ? AppColors.danger : AppColors.textMuted,
                  ),
                ),
              ),
              if (failed)
                InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(AppSpace.radiusPill),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => showNotWired(context, 'MMS attachments'),
                icon: const Icon(Icons.attach_file),
                color: AppColors.textSecondary,
                tooltip: 'Attach',
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !sending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg,
                      vertical: AppSpace.md,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => showNotWired(context, 'The emoji picker'),
                      icon: const Icon(Icons.emoji_emotions_outlined),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpace.radiusPill),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpace.radiusPill),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpace.radiusPill),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              SizedBox(
                width: 52,
                height: 52,
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpace.radiusField),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: sending ? null : onSend,
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(15),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
