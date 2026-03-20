import 'package:flutter/material.dart';

enum AppTextVariant { title, subtitle, body, caption, label }

class AppText extends StatelessWidget {
  final String text;
  final AppTextVariant variant;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextStyle? style;

  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final base = switch (variant) {
      AppTextVariant.title => textTheme.titleLarge,
      AppTextVariant.subtitle => textTheme.titleMedium,
      AppTextVariant.body => textTheme.bodyLarge,
      AppTextVariant.caption => textTheme.bodyMedium?.copyWith(fontSize: 12),
      AppTextVariant.label => textTheme.labelLarge,
    };

    final resolved = (base ?? const TextStyle()).copyWith(
      color: color,
      fontWeight: fontWeight,
      fontSize: fontSize,
    );

    return Text(
      text,
      style: resolved.merge(style),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
