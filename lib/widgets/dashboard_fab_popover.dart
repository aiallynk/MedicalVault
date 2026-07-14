import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashboardFabPopover extends StatelessWidget {
  const DashboardFabPopover({
    super.key,
    required this.isOpen,
    required this.animation,
    required this.onAiAssistant,
    required this.onNearbyHealthcare,
    required this.onProducts,
    required this.onAppointments,
    required this.onFamilyCare,
  });

  final bool isOpen;
  final Animation<double> animation;
  final VoidCallback onAiAssistant;
  final VoidCallback onNearbyHealthcare;
  final VoidCallback onProducts;
  final VoidCallback onAppointments;
  final VoidCallback onFamilyCare;

  static const _fabSize = 58.0;
  static const _fabToCardGap = 12.0;
  static const _bottomNavigationOffset = 112.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rightInset = media.size.width >= 600 ? 24.0 : 16.0;
    final maxCardWidth = math.max(0.0, media.size.width - rightInset - 12.0);
    final cardWidth = math.min(260.0, maxCardWidth);
    final bottom = _bottomNavigationOffset +
        media.padding.bottom +
        _fabSize +
        _fabToCardGap;
    final availableHeight = math.max(
      0.0,
      media.size.height - media.padding.top - bottom - 12.0,
    );

    final actions = <_DashboardFabAction>[
      _DashboardFabAction(
        icon: Icons.smart_toy_rounded,
        label: 'AI Assistant',
        onTap: onAiAssistant,
      ),
      _DashboardFabAction(
        icon: Icons.local_hospital_rounded,
        label: 'Nearby Healthcare',
        onTap: onNearbyHealthcare,
      ),
      _DashboardFabAction(
        icon: Icons.shopping_bag_rounded,
        label: 'Products',
        onTap: onProducts,
      ),
      _DashboardFabAction(
        icon: Icons.calendar_month_rounded,
        label: 'Appointments',
        onTap: onAppointments,
      ),
      _DashboardFabAction(
        icon: Icons.family_restroom_rounded,
        label: 'Family Care',
        onTap: onFamilyCare,
      ),
    ];

    return Positioned(
      right: rightInset,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final progress = Curves.easeOutCubic.transform(animation.value);
          return IgnorePointer(
            ignoring: !isOpen || animation.value < 0.04,
            child: Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, (1 - progress) * 10),
                child: Transform.scale(
                  alignment: Alignment.bottomRight,
                  scale: 0.96 + (0.04 * progress),
                  child: SizedBox(
                    width: cardWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: availableHeight),
                      child: _DashboardFabPopoverCard(actions: actions),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardFabPopoverCard extends StatelessWidget {
  const _DashboardFabPopoverCard({required this.actions});

  final List<_DashboardFabAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = theme.brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : Colors.white;

    return Material(
      color: surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              _DashboardFabActionRow(action: actions[index]),
              if (index != actions.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardFabActionRow extends StatelessWidget {
  const _DashboardFabActionRow({required this.action});

  final _DashboardFabAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, size: 20, color: scheme.primary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardFabAction {
  const _DashboardFabAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
