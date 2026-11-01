// lib/integrations/wapcentral/ads/house_ad_card.dart
//
// A WebAppyPie house ad, rendered only from a campaign WAPCentral returned in `customAdFallback`. Always
// labelled "Ad". The impression is reported once, when at least half the card is really visible.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wap_ads_sdk/wap_ads.dart';

class HouseAdCard extends StatefulWidget {
  const HouseAdCard({
    super.key,
    required this.campaign,
    required this.onShown,
    required this.onTap,
    this.compact = false,
  });

  final CustomAdFallback campaign;
  final VoidCallback onShown;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<HouseAdCard> createState() => _HouseAdCardState();
}

class _HouseAdCardState extends State<HouseAdCard> {
  bool _shown = false;

  Future<void> _open() async {
    widget.onTap();
    final uri = Uri.tryParse(widget.campaign.destinationUrl);
    if (uri == null || uri.scheme != 'https') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.campaign;
    final image = c.thumbnailUrl ?? c.imageUrl;
    return VisibilityDetector(
      key: ValueKey('house_ad_${c.campaignId}_$hashCode'),
      onVisibilityChanged: (info) {
        if (!_shown && info.visibleFraction >= 0.5) {
          _shown = true;
          widget.onShown();
        }
      },
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _open,
          child: Semantics(
            button: true,
            label: ['Advertisement', c.title, c.description, c.ctaText].where((e) => e.isNotEmpty).join('. '),
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 8 : 12),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    if (!widget.compact && image != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(width: 56),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const AdLabel(),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(c.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                            ),
                          ]),
                          if (c.description.isNotEmpty)
                            Text(c.description,
                                maxLines: widget.compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(c.ctaText.isEmpty ? 'Open' : c.ctaText,
                        style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small "Ad" disclosure chip.
class AdLabel extends StatelessWidget {
  const AdLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('Ad', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
