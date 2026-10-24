// lib/core/widgets/source_badge.dart
//
// Subtle, professional source badges for media items (REQ-10).
// Distinguishes WhatsApp vs WhatsApp Business without brand infringement.

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../services/media_access/media_item.dart';

class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.sourceApp,
    this.useShortLabel = true,
  });

  /// Package name (e.g. 'com.whatsapp', 'com.whatsapp.w4b') or source string.
  final String sourceApp;
  final bool useShortLabel;

  @override
  Widget build(BuildContext context) {
    final isBusiness = sourceApp.toLowerCase().contains('business') ||
        sourceApp.toLowerCase().contains('w4b');
    final scheme = Theme.of(context).colorScheme;

    final label = isBusiness
        ? (useShortLabel ? 'Business' : 'WhatsApp Business')
        : (useShortLabel ? 'WA' : 'WhatsApp');

    final bgColor = isBusiness
        ? scheme.secondaryContainer.withValues(alpha: 0.7)
        : scheme.surfaceContainerHighest;

    final textColor = isBusiness
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    final icon = isBusiness
        ? Icons.business_center_outlined
        : Icons.chat_bubble_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(
          color: isBusiness
              ? scheme.secondary.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
