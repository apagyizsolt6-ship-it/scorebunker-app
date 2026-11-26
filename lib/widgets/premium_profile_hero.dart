import 'package:flutter/material.dart';

/// Egységes, prémium fejléc csapat- és játékosprofilokhoz.
class PremiumProfileHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String eyebrow;
  final String imageUrl;
  final IconData fallbackIcon;
  final Widget? fallback;

  const PremiumProfileHero({
    super.key,
    required this.title,
    this.subtitle = '',
    this.eyebrow = '',
    this.imageUrl = '',
    this.fallbackIcon = Icons.sports_soccer_rounded,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = scheme.primary.withValues(alpha: dark ? 0.34 : 0.22);
    final image = imageUrl.trim();

    Widget avatar() {
      final placeholder = fallback ?? Icon(fallbackIcon, size: 34, color: scheme.primary);
      if (image.isEmpty) return placeholder;
      return Image.network(
        image,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: dark ? 0.20 : 0.11),
            scheme.tertiary.withValues(alpha: dark ? 0.13 : 0.07),
            scheme.surface,
          ],
        ),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: dark ? 0.10 : 0.06),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: dark ? 0.76 : 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Center(child: avatar()),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow.trim().isNotEmpty) ...[
                  Text(
                    eyebrow.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_forward_ios_rounded, size: 13, color: scheme.primary.withValues(alpha: 0.65)),
      ],
    ),
  );
  }
}
