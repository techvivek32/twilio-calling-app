import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class MessageDetailsScreen extends StatefulWidget {
  const MessageDetailsScreen({
    super.key,
    required this.message,
    required this.peerNumber,
    required this.peerName,
    this.session,
  });

  final ChatMessage message;
  final String peerNumber;
  final String peerName;
  final AppSession? session;

  @override
  State<MessageDetailsScreen> createState() => _MessageDetailsScreenState();
}

class _MessageDetailsScreenState extends State<MessageDetailsScreen> {
  late ChatMessage _message = widget.message;
  bool _resending = false;

  AppSession get _session => widget.session ?? AppSession.instance;

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    _toast('$label copied to clipboard.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);

    try {
      final result = await _session.sendMessage(
        to: widget.peerNumber,
        body: _message.body,
        contactName: widget.peerName,
      );
      if (!mounted) return;
      setState(() => _message = result.message);
      _toast(result.warning ?? 'Message resent.');
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = _message.failed;
    final ownNumber = _session.number?.formatted ?? 'Not assigned';

    return Scaffold(
      body: Column(
        children: [
          BrandHeader(
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              tooltip: 'Back',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => showNotWired(context, 'Notification center'),
                  icon: const Icon(Icons.notifications_none),
                  color: AppColors.textPrimary,
                ),
                InitialsAvatar(name: widget.peerName, size: 36),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xxl,
              ),
              children: [
                Text(
                  'Message Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpace.xs),
                const Text(
                  'Review full message content, delivery status, and routing '
                  'metadata.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpace.sm),
                          const Expanded(child: CardLabel('Message Content')),
                          failed
                              ? StatusPill.danger(_message.status.label)
                              : StatusPill.success(_message.status.label),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpace.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(
                            AppSpace.radiusField,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _message.body,
                          style: const TextStyle(fontSize: 16.5, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: FilledButton.icon(
                              onPressed: _resending ? null : _resend,
                              icon: _resending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 20),
                              label: const Text('Resend'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                textStyle: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            flex: 4,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _copy(_message.body, 'Message body'),
                              icon: const Icon(Icons.copy_outlined, size: 20),
                              label: const Text('Copy'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                textStyle: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.alt_route,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: AppSpace.sm),
                          CardLabel('Routing'),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      const Divider(),
                      const SizedBox(height: AppSpace.lg),
                      _CopyRow(
                        label: _message.fromMe
                            ? 'From (Sender)'
                            : 'From (Contact)',
                        value: _message.fromMe
                            ? ownNumber
                            : formatPhoneNumber(widget.peerNumber),
                        onCopy: () => _copy(
                          _message.fromMe
                              ? (_session.number?.phoneNumber ?? '')
                              : widget.peerNumber,
                          'Sender number',
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _CopyRow(
                        label: 'To (Recipient)',
                        value: _message.fromMe
                            ? formatPhoneNumber(widget.peerNumber)
                            : ownNumber,
                        onCopy: () => _copy(
                          _message.fromMe
                              ? widget.peerNumber
                              : (_session.number?.phoneNumber ?? ''),
                          'Recipient number',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: AppSpace.sm),
                          CardLabel('System Info'),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      const Divider(),
                      const SizedBox(height: AppSpace.lg),
                      _InfoRow(
                        label: 'Time Sent',
                        value: formatFullTimestamp(_message.sentAt),
                      ),
                      const SizedBox(height: AppSpace.md),
                      _InfoRow(
                        label: 'Delivery status',
                        value: _message.status.label,
                      ),
                      const SizedBox(height: AppSpace.md),
                      const Divider(),
                      const SizedBox(height: AppSpace.md),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Message ID',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _copy(_message.id, 'Message ID'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _message.id.length > 10
                                      ? '${_message.id.substring(0, 10)}...'
                                      : _message.id,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.copy_outlined,
                                  size: 17,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
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

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: onCopy,
              child: const Icon(
                Icons.copy_outlined,
                size: 19,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
