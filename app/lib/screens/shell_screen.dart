import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import 'call_history_screen.dart';
import 'dialer_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';

/// Tabs of the persistent bottom navigation.
enum ShellTab { home, calls, messages, settings }

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.initialTab = ShellTab.home, this.session});

  final ShellTab initialTab;
  final AppSession? session;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late ShellTab _tab = widget.initialTab;
  bool _dialerOpen = false;

  AppSession get _session => widget.session ?? AppSession.instance;

  void _selectTab(ShellTab tab) {
    setState(() {
      if (_tab == ShellTab.calls && tab == ShellTab.calls) {
        _dialerOpen = false;
      }
      _tab = tab;
      if (tab != ShellTab.calls) _dialerOpen = false;
    });
  }

  void _openDialer() {
    setState(() {
      _tab = ShellTab.calls;
      _dialerOpen = true;
    });
  }

  void _closeDialer() => setState(() => _dialerOpen = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) {
        ShellTab.home => HomeScreen(
          session: _session,
          onOpenDialer: _openDialer,
          onOpenTab: _selectTab,
        ),
        ShellTab.calls => _dialerOpen
            ? DialerScreen(session: _session, onShowHistory: _closeDialer)
            : CallHistoryScreen(
                session: _session,
                onOpenDialer: _openDialer,
              ),
        ShellTab.messages => MessagesScreen(session: _session),
        ShellTab.settings => SettingsScreen(session: _session),
      },
      bottomNavigationBar: AppBottomNav(current: _tab, onSelect: _selectTab),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: current == ShellTab.home,
                onTap: () => onSelect(ShellTab.home),
              ),
              _NavItem(
                icon: Icons.phone_outlined,
                activeIcon: Icons.phone_rounded,
                label: 'Calls',
                selected: current == ShellTab.calls,
                onTap: () => onSelect(ShellTab.calls),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Messages',
                selected: current == ShellTab.messages,
                showBadge: true,
                onTap: () => onSelect(ShellTab.messages),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                selected: current == ShellTab.settings,
                onTap: () => onSelect(ShellTab.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpace.radiusField),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? activeIcon : icon,
                    size: 24,
                    color: foreground,
                  ),
                  if (showBadge && !selected)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
