import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Initials avatar with a deterministic tint per person.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.initials,
    this.showPersonIcon = false,
  });

  final String name;
  final double size;
  final String? initials;
  final bool showPersonIcon;

  static const List<Color> _tints = [
    Color(0xFFDCE7FB),
    Color(0xFFE7E1FA),
    Color(0xFFFBE3DC),
    Color(0xFFDDF3E6),
    Color(0xFFFAF0D8),
    Color(0xFFE2EFF7),
  ];

  static const List<Color> _inks = [
    Color(0xFF1D4ED8),
    Color(0xFF5B34C4),
    Color(0xFFB2451D),
    Color(0xFF11774A),
    Color(0xFF8A6212),
    Color(0xFF1B5F80),
  ];

  String get _resolvedInitials {
    if (initials != null) return initials!;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final index = name.hashCode.abs() % _tints.length;
    final showIcon = showPersonIcon || _resolvedInitials == '?';

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: showIcon ? AppColors.surfaceMuted : _tints[index],
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: showIcon
          ? Icon(
              Icons.person_outline,
              size: size * 0.5,
              color: AppColors.textMuted,
            )
          : Text(
              _resolvedInitials,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: _inks[index],
                letterSpacing: 0.2,
              ),
            ),
    );
  }
}

/// White rounded panel used for every grouped block in the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.margin,
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpace.radiusCard);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small uppercase caption that heads most cards in the mockups.
class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key, this.color = AppColors.textSecondary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: color,
      ),
    );
  }
}

/// Rounded status pill, e.g. Connected or Missed.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.showDot = true,
  });

  const StatusPill.success(this.text, {super.key})
    : background = AppColors.successSoft,
      foreground = AppColors.successText,
      showDot = true;

  const StatusPill.danger(this.text, {super.key})
    : background = AppColors.dangerSoft,
      foreground = AppColors.danger,
      showDot = true;

  final String text;
  final Color background;
  final Color foreground;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpace.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular icon button used by the dialer, in-call controls and headers.
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 64,
    this.background = AppColors.surface,
    this.foreground = AppColors.textPrimary,
    this.borderColor = AppColors.border,
    this.iconSize,
    this.glowColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final double? iconSize;
  final Color? glowColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: glowColor == null
            ? null
            : [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.34),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: iconSize ?? size * 0.42, color: foreground),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Shared Business Connect top bar.
class BrandHeader extends StatelessWidget implements PreferredSizeWidget {
  const BrandHeader({
    super.key,
    this.leading,
    this.trailing,
    this.title = 'Business Connect',
    this.showBell = true,
    this.bellHasBadge = false,
    this.onBellTap,
  });

  final Widget? leading;
  final Widget? trailing;
  final String title;
  final bool showBell;
  final bool bellHasBadge;
  final VoidCallback? onBellTap;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              const SizedBox(width: AppSpace.md),
              if (leading != null) leading! else const SizedBox(width: 40),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else if (showBell)
                _Bell(hasBadge: bellHasBadge, onTap: onBellTap)
              else
                const SizedBox(width: 40),
              const SizedBox(width: AppSpace.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.hasBadge, this.onTap});

  final bool hasBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.notifications_none),
            color: AppColors.textPrimary,
            iconSize: 24,
            padding: EdgeInsets.zero,
          ),
          if (hasBadge)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void showNotWired(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$feature is not wired to Twilio in this build.')),
    );
}
