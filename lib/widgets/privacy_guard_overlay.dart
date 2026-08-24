import 'dart:ui';

import 'package:flutter/material.dart';

/// Hides app content behind an opaque cover while the app is backgrounded
/// or mid-transition (task switcher, incoming call, notification shade),
/// so a medical document, chat message, or session detail is never visible
/// in the OS app-switcher thumbnail. Applies to both platforms uniformly;
/// on Android this is a second layer on top of `FLAG_SECURE` (set natively
/// in `MainActivity.kt`), which iOS has no equivalent of, so this is the
/// only app-switcher protection iOS gets.
///
/// Wrap the app's root child with this once, at the [MaterialApp.builder]
/// level, so every screen is covered without per-screen wiring.
class PrivacyGuardOverlay extends StatefulWidget {
  const PrivacyGuardOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<PrivacyGuardOverlay> createState() => _PrivacyGuardOverlayState();
}

class _PrivacyGuardOverlayState extends State<PrivacyGuardOverlay>
    with WidgetsBindingObserver {
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldHide = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (shouldHide != _hidden && mounted) {
      setState(() => _hidden = shouldHide);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_hidden)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                color: Theme.of(context).colorScheme.surface.withValues(
                      alpha: 0.92,
                    ),
                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
