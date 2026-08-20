import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'call_ended_screen.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({
    super.key,
    required this.name,
    required this.phone,
    this.rawNumber,
    this.contactName = '',
    this.role,
    this.callSid,
    this.warning,
    this.session,
  });

  final String name;
  final String phone;

  /// Digits to log against; falls back to [phone] when not supplied.
  final String? rawNumber;
  final String contactName;
  final String? role;

  /// Set when Twilio accepted the call; null means it was not placed.
  final String? callSid;

  /// Why the call could not be placed, if it could not.
  final String? warning;
  final AppSession? session;

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speaker = false;
  bool _onHold = false;
  bool _ending = false;

  AppSession get _session => widget.session ?? AppSession.instance;

  bool get _live => widget.callSid != null && widget.callSid!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_onHold && mounted) setState(() => _seconds++);
    });

    if (widget.warning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(widget.warning!)));
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _endCall() async {
    if (_ending) return;
    setState(() => _ending = true);
    _timer?.cancel();

    // Record the call so it reaches history and the admin panel. A live call
    // was already logged server-side when Twilio accepted it.
    if (!_live) {
      try {
        await _session.logCall(
          to: widget.rawNumber ?? widget.phone,
          durationSec: _seconds,
          contactName: widget.contactName,
          status: 'failed',
        );
      } catch (_) {
        // Never block hanging up on a logging failure.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallEndedScreen(
          name: widget.name,
          phone: widget.phone,
          rawNumber: widget.rawNumber,
          contactName: widget.contactName,
          role: widget.role,
          durationLabel: formatDuration(_seconds),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.lg,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                    color: AppColors.textSecondary,
                    tooltip: 'Minimise call',
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  const Flexible(
                    child: Text(
                      'END-TO-END ENCRYPTED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpace.xl),
                    InitialsAvatar(name: widget.name, size: 132),
                    const SizedBox(height: AppSpace.xl),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      widget.phone,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      formatClock(_seconds),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    _StatusPillRow(live: _live, onHold: _onHold),
                    const SizedBox(height: AppSpace.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallControl(
                          icon: _muted ? Icons.mic_off : Icons.mic_none,
                          label: 'Mute',
                          active: _muted,
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _CallControl(
                          icon: Icons.dialpad,
                          label: 'Keypad',
                          onTap: () => showNotWired(context, 'In-call keypad'),
                        ),
                        _CallControl(
                          icon: _speaker
                              ? Icons.volume_up
                              : Icons.volume_up_outlined,
                          label: 'Speaker',
                          active: _speaker,
                          onTap: () => setState(() => _speaker = !_speaker),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallControl(
                          icon: Icons.person_add_alt,
                          label: 'Add Call',
                          onTap: () =>
                              showNotWired(context, 'Conference calling'),
                        ),
                        _CallControl(
                          icon: Icons.pause,
                          label: 'Hold',
                          active: _onHold,
                          onTap: () => setState(() => _onHold = !_onHold),
                        ),
                        const _CallControl(
                          icon: Icons.videocam_off_outlined,
                          label: 'Video',
                          disabled: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    CircleActionButton(
                      icon: Icons.call_end,
                      size: 84,
                      iconSize: 36,
                      background: AppColors.dangerDeep,
                      foreground: Colors.white,
                      borderColor: null,
                      glowColor: AppColors.dangerDeep,
                      onTap: _ending ? null : _endCall,
                      tooltip: 'End call',
                    ),
                    const SizedBox(height: AppSpace.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPillRow extends StatelessWidget {
  const _StatusPillRow({required this.live, required this.onHold});

  final bool live;
  final bool onHold;

  @override
  Widget build(BuildContext context) {
    final label = onHold
        ? 'ON HOLD'
        : live
        ? 'CONNECTED VIA TWILIO'
        : 'NOT CONNECTED';
    final color = live && !onHold ? AppColors.primary : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: live ? AppColors.primarySoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpace.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: live ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final Color foreground;
    final Color background;
    final Color? borderColor;

    if (disabled) {
      foreground = AppColors.textMuted;
      background = AppColors.surface;
      borderColor = AppColors.border;
    } else if (active) {
      foreground = Colors.white;
      background = AppColors.primaryDark;
      borderColor = null;
    } else {
      foreground = AppColors.textPrimary;
      background = AppColors.surface;
      borderColor = AppColors.border;
    }

    return Column(
      children: [
        CircleActionButton(
          icon: icon,
          size: 72,
          iconSize: 28,
          background: background,
          foreground: foreground,
          borderColor: borderColor,
          onTap: disabled ? null : onTap,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: disabled
                ? AppColors.textMuted
                : active
                ? AppColors.primaryDark
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
