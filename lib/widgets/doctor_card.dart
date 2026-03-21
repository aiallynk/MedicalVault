import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../api_service.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import 'app_text.dart';
import 'custom_card.dart';

class DoctorCard extends StatelessWidget {
  static final Map<int, ImageProvider?> _dataUriCache = {};

  final String name;
  final String specialization;
  final double rating;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool compact;
  final bool glass;

  const DoctorCard({
    super.key,
    required this.name,
    required this.specialization,
    required this.rating,
    this.imageUrl,
    this.onTap,
    this.highlighted = false,
    this.compact = false,
    this.glass = false,
  });

  ImageProvider? _buildAvatarImageProvider(String? rawImageUrl) {
    final source = rawImageUrl?.trim() ?? '';
    if (source.isEmpty) return null;

    if (source.startsWith('data:image/')) {
      if (source.length > 250000) return null;
      final cacheKey = source.hashCode;
      if (_dataUriCache.containsKey(cacheKey)) {
        return _dataUriCache[cacheKey];
      }
      final commaIndex = source.indexOf(',');
      if (commaIndex > 0 && commaIndex < source.length - 1) {
        final metadata = source.substring(0, commaIndex).toLowerCase();
        if (metadata.contains(';base64')) {
          final base64Payload = source.substring(commaIndex + 1).trim();
          if (base64Payload.isNotEmpty) {
            try {
              final bytes = base64Decode(base64Payload);
              final image = MemoryImage(Uint8List.fromList(bytes));
              _dataUriCache[cacheKey] = image;
              return image;
            } catch (_) {
              _dataUriCache[cacheKey] = null;
              return null;
            }
          }
        }
      }
      _dataUriCache[cacheKey] = null;
      return null;
    }

    final resolvedSource = ApiService.resolveMediaUrl(source);
    if (resolvedSource == null || resolvedSource.isEmpty) return null;
    return NetworkImage(resolvedSource);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final textSecondary = theme.textTheme.bodyMedium?.color ?? Colors.black54;
    final gradient = highlighted
        ? [
            primary.withValues(alpha: 0.92),
            secondary.withValues(alpha: 0.92),
          ]
        : null;

    final contentColor = highlighted ? Colors.white : textPrimary;
    final secondaryColor =
        highlighted ? Colors.white.withValues(alpha: 0.84) : textSecondary;
    final avatarImage = _buildAvatarImageProvider(imageUrl);

    return CustomCard(
      onTap: onTap,
      gradient: gradient,
      glass: !highlighted && glass,
      softShadow: highlighted,
      radius: AppRadii.large,
      padding: EdgeInsets.all(compact ? 12 : AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: compact ? 18 : 22,
                backgroundColor: highlighted
                    ? Colors.white.withValues(alpha: 0.24)
                    : primary.withValues(alpha: 0.14),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Icon(
                        Icons.medical_services_rounded,
                        color: highlighted ? Colors.white : primary,
                        size: compact ? 20 : 24,
                      )
                    : null,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.22)
                      : primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: highlighted ? Colors.white : Colors.amber.shade700,
                    ),
                    const SizedBox(width: 2),
                    AppText(
                      rating.toStringAsFixed(1),
                      variant: AppTextVariant.caption,
                      color: contentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          AppText(
            name,
            variant: compact ? AppTextVariant.body : AppTextVariant.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            color: contentColor,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 4),
          AppText(
            specialization.isEmpty ? 'General Medicine' : specialization,
            variant: AppTextVariant.caption,
            color: secondaryColor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: contentColor,
                ),
                const SizedBox(width: 4),
                AppText(
                  'View details',
                  variant: AppTextVariant.caption,
                  color: secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
