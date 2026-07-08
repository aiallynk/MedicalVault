import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../api_service.dart';

class LostPersonPhoto extends StatelessWidget {
  const LostPersonPhoto({
    super.key,
    required this.photoUrl,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.person_search_rounded,
    this.semanticsLabel = 'Lost person photo',
  });

  final String? photoUrl;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;
  final String semanticsLabel;

  Uint8List? _decodeDataImage(String value) {
    if (!value.startsWith('data:image/')) return null;
    final commaIndex = value.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= value.length - 1) return null;
    final metadata = value.substring(0, commaIndex).toLowerCase();
    if (!metadata.contains(';base64')) return null;
    try {
      return base64Decode(value.substring(commaIndex + 1).trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiService.resolveMediaUrl(photoUrl);
    final theme = Theme.of(context);
    final fallback = _FallbackPhoto(
      width: width,
      height: height,
      icon: fallbackIcon,
      color: theme.colorScheme.surfaceContainerHighest,
      iconColor: theme.colorScheme.onSurfaceVariant,
    );

    Widget child = fallback;
    if (resolvedUrl != null) {
      final embeddedBytes = _decodeDataImage(resolvedUrl);
      if (embeddedBytes != null) {
        child = Image.memory(
          embeddedBytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      } else {
        child = Image.network(
          resolvedUrl,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          loadingBuilder: (context, image, loadingProgress) {
            if (loadingProgress == null) return image;
            final expected = loadingProgress.expectedTotalBytes;
            return _LoadingPhoto(
              width: width,
              height: height,
              value: expected != null && expected > 0
                  ? loadingProgress.cumulativeBytesLoaded / expected
                  : null,
            );
          },
          errorBuilder: (_, __, ___) => fallback,
        );
      }
    }

    return Semantics(
      image: true,
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class _LoadingPhoto extends StatelessWidget {
  const _LoadingPhoto({
    required this.width,
    required this.height,
    required this.value,
  });

  final double? width;
  final double? height;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: value,
          ),
        ),
      ),
    );
  }
}

class _FallbackPhoto extends StatelessWidget {
  const _FallbackPhoto({
    required this.width,
    required this.height,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final double? width;
  final double? height;
  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: color,
      child: Icon(icon, color: iconColor, size: 34),
    );
  }
}
