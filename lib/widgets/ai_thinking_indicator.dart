import 'package:flutter/material.dart';

/// Medical-themed "thinking" indicator shown while an AI assistant is
/// generating a reply. Cycles through phase labels (like Claude's
/// "Thinking / Exploring") alongside an animated 3-dot pulse.
class AiThinkingIndicator extends StatefulWidget {
  const AiThinkingIndicator({
    super.key,
    this.phrases = const [
      'Reviewing records…',
      'Searching reports…',
      'Cross-checking matches…',
      'Preparing answer…',
    ],
    this.avatarIcon = Icons.health_and_safety_rounded,
  });

  final List<String> phrases;
  final IconData avatarIcon;

  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _dotsController;
  late final Animation<double> _dotsAnimation;
  late final AnimationController _phraseController;
  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _dotsAnimation = CurvedAnimation(
      parent: _dotsController,
      curve: Curves.easeInOut,
    );

    _phraseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _phraseController.addListener(() {
      if (_phraseController.value >= 0.999 && widget.phrases.length > 1) {
        setState(() {
          _phraseIndex = (_phraseIndex + 1) % widget.phrases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotsAnimation,
      builder: (context, child) {
        final phase = (_dotsAnimation.value + (index * 0.2)) % 1.0;
        final opacity = 0.3 + 0.7 * (0.5 + 0.5 * (1 - (phase - 0.5).abs() * 2));
        return Opacity(opacity: opacity.clamp(0.3, 1.0), child: child);
      },
      child: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.phrases.isNotEmpty
        ? widget.phrases[_phraseIndex % widget.phrases.length]
        : '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                widget.avatarIcon,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDot(0),
                  _buildDot(1),
                  _buildDot(2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact 3-dot "typing" bubble for human-to-human chats (no phase label).
class TypingDotsBubble extends StatefulWidget {
  const TypingDotsBubble({super.key});

  @override
  State<TypingDotsBubble> createState() => _TypingDotsBubbleState();
}

class _TypingDotsBubbleState extends State<TypingDotsBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final phase = (_animation.value + (index * 0.2)) % 1.0;
        final opacity = 0.3 + 0.7 * (0.5 + 0.5 * (1 - (phase - 0.5).abs() * 2));
        return Opacity(opacity: opacity.clamp(0.3, 1.0), child: child);
      },
      child: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_buildDot(0), _buildDot(1), _buildDot(2)],
        ),
      ),
    );
  }
}
