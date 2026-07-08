import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/app_navigator.dart';
import '../screens/chat_screen.dart';

const String _aiFabXKey = 'ai_fab_x';
const String _aiFabYKey = 'ai_fab_y';

class AIAssistantOverlayController {
  AIAssistantOverlayController._();

  static final ValueNotifier<bool> _visible = ValueNotifier<bool>(true);

  static ValueListenable<bool> get visibilityListenable => _visible;

  static bool get isVisible => _visible.value;

  static void setVisible(bool visible) {
    if (_visible.value == visible) return;
    _visible.value = visible;
  }
}

Future<void> resetAIAssistantButtonPosition() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_aiFabXKey);
  await prefs.remove(_aiFabYKey);
}

class AIFloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  const AIFloatingButton({
    super.key,
    this.onPressed,
    this.size = 112,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            'assets/chatbot.json',
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
      ),
    );
  }
}

class DraggableAIAssistantOverlay extends StatefulWidget {
  final Widget child;
  final ValueListenable<String?>? routeNameListenable;
  final Set<String> hiddenRouteNames;
  final Set<String> visibleRouteNames;
  final bool enabled;

  const DraggableAIAssistantOverlay({
    super.key,
    required this.child,
    this.routeNameListenable,
    this.hiddenRouteNames = const <String>{},
    this.visibleRouteNames = const <String>{},
    this.enabled = true,
  });

  @override
  State<DraggableAIAssistantOverlay> createState() =>
      _DraggableAIAssistantOverlayState();
}

class _DraggableAIAssistantOverlayState
    extends State<DraggableAIAssistantOverlay> {
  static const double _fabSize = 112;
  static const double _padding = 8;
  static const double _dragThreshold = 8;

  Offset? _position;
  bool _positionLoaded = false;
  bool _dragMoved = false;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_aiFabXKey);
    final y = prefs.getDouble(_aiFabYKey);
    if (!mounted) return;
    setState(() {
      if (x != null && y != null) {
        _position = Offset(x, y);
      }
      _positionLoaded = true;
    });
  }

  Future<void> _persistPosition(Offset value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_aiFabXKey, value.dx);
    await prefs.setDouble(_aiFabYKey, value.dy);
  }

  void _navigateToChat() {
    final navigator = appNavigatorKey.currentState ??
        Navigator.of(context, rootNavigator: true);

    navigator.push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChatScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideTween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(
            CurveTween(curve: Curves.easeOutCubic),
          );
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return SlideTransition(
            position: animation.drive(slideTween),
            child: FadeTransition(opacity: fade, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  Offset _clampOffset(Offset candidate, Size size, EdgeInsets insets) {
    final minX = _padding;
    final minY = insets.top + _padding;
    final maxX = size.width - _fabSize - _padding;
    final maxY = size.height - _fabSize - insets.bottom - _padding;

    return Offset(
      candidate.dx.clamp(minX, maxX),
      candidate.dy.clamp(minY, maxY),
    );
  }

  Offset _defaultOffset(Size size, EdgeInsets insets) {
    final x = size.width - _fabSize - 12;
    final y = size.height - _fabSize - insets.bottom - 130;
    return _clampOffset(Offset(x, y), size, insets);
  }

  bool _shouldShowFabForRoute(String? routeName) {
    if (widget.visibleRouteNames.isNotEmpty) {
      return routeName != null && widget.visibleRouteNames.contains(routeName);
    }
    return routeName == null || !widget.hiddenRouteNames.contains(routeName);
  }

  Widget _buildOverlay({
    required Size size,
    required EdgeInsets insets,
    required bool showFab,
    required bool aiVisible,
  }) {
    final position =
        _clampOffset(_position ?? _defaultOffset(size, insets), size, insets);
    _position = position;

    return Stack(
      children: [
        widget.child,
        if (showFab)
          Positioned(
            left: position.dx,
            top: position.dy,
            child: IgnorePointer(
              ignoring: !aiVisible,
              child: AnimatedOpacity(
                opacity: aiVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: GestureDetector(
                  onPanStart: (_) {
                    _dragMoved = false;
                    _dragDistance = 0;
                  },
                  onPanUpdate: (details) {
                    final next = _clampOffset(
                      Offset(
                        (_position?.dx ?? position.dx) + details.delta.dx,
                        (_position?.dy ?? position.dy) + details.delta.dy,
                      ),
                      size,
                      insets,
                    );

                    _dragDistance += details.delta.distance;
                    if (_dragDistance > _dragThreshold) {
                      _dragMoved = true;
                    }

                    setState(() {
                      _position = next;
                    });
                  },
                  onPanEnd: (_) {
                    if (_position != null) {
                      _persistPosition(_position!);
                    }
                    _dragMoved = false;
                    _dragDistance = 0;
                  },
                  onPanCancel: () {
                    _dragMoved = false;
                    _dragDistance = 0;
                  },
                  child: AIFloatingButton(
                    onPressed: () {
                      if (!_dragMoved) {
                        _navigateToChat();
                      }
                    },
                    size: _fabSize,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final size = constraints.biggest;
        final insets = media.padding;

        if (!_positionLoaded) {
          return widget.child;
        }

        if (widget.routeNameListenable == null) {
          final showFab = widget.visibleRouteNames.isEmpty;
          return ValueListenableBuilder<bool>(
            valueListenable: AIAssistantOverlayController.visibilityListenable,
            builder: (context, aiVisible, _) => _buildOverlay(
              size: size,
              insets: insets,
              showFab: showFab,
              aiVisible: aiVisible,
            ),
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: widget.routeNameListenable!,
          builder: (context, routeName, child) => ValueListenableBuilder<bool>(
            valueListenable: AIAssistantOverlayController.visibilityListenable,
            builder: (context, aiVisible, _) {
              final showFab = _shouldShowFabForRoute(routeName);
              return _buildOverlay(
                size: size,
                insets: insets,
                showFab: showFab,
                aiVisible: aiVisible,
              );
            },
          ),
        );
      },
    );
  }
}
