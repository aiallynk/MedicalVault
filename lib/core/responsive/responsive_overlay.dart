import 'package:flutter/material.dart';

import 'responsive_tokens.dart';

/// Wraps dialog content with a tablet-safe max width and a scroll view so
/// long content (large text scale, long lists) never gets clipped by a
/// dialog's implicit size constraints. Use as the `child` passed to
/// `showDialog`'s builder instead of returning an unconstrained `AlertDialog`
/// content widget directly.
class ResponsiveDialogContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveDialogContent({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Leave room for the dialog's own margin plus keyboard insets so a form
    // dialog opened with the keyboard up still has scrollable headroom.
    final maxHeight = mq.size.height - mq.viewInsets.bottom - 96;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight > 200 ? maxHeight : 200,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}

/// Shows a bottom sheet whose content is width-capped on tablets/expanded
/// screens (centered, not stretched edge-to-edge), keyboard- and
/// safe-area-aware, and scrollable so long content never overflows.
///
/// Use in place of a raw `showModalBottomSheet` call when the sheet holds a
/// form, a list of options, or any content whose height depends on text
/// scale.
Future<T?> showResponsiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  double maxWidth = AppResponsive.maxContentWidth,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    shape: shape,
    builder: (sheetContext) {
      final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: builder(sheetContext),
          ),
        ),
      );
    },
  );
}
