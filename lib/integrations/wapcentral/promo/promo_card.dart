// lib/integrations/wapcentral/promo/promo_card.dart
//
// Promotion card for Home. Renders nothing (zero height) unless WAPCentral returned a valid, signed campaign.
// Labelled with the campaign's sponsor label; the impression counts only when at least half the card is visible.
// Not for use in the Private Folder, viewer, editors, permission setup or next to destructive actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wap_promo_sdk/wap_promo_sdk.dart';

import 'promo_controller.dart';

class PromoCard extends ConsumerStatefulWidget {
  const PromoCard({super.key, this.padding = EdgeInsets.zero});

  /// Applied only while a campaign is showing.
  final EdgeInsets padding;

  @override
  ConsumerState<PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends ConsumerState<PromoCard> {
  String? _countedFor;

  Future<void> _open(PromoPayload p) async {
    ref.read(promoControllerProvider.notifier).recordClick(p);
    final uri = PromoController.safeDestination(p);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(promoControllerProvider);
    if (p == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final image = Uri.tryParse(p.imageUrl ?? '');
    return Padding(
      padding: widget.padding,
      child: VisibilityDetector(
        key: ValueKey('promo_${p.campaignId}'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction >= 0.5 && _countedFor != p.campaignId) {
            _countedFor = p.campaignId;
            ref.read(promoControllerProvider.notifier).recordImpression(p);
          }
        },
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(p),
            child: Semantics(
              button: true,
              label: [p.sponsorLabel ?? 'Promotion', p.title, p.description, p.ctaText]
                  .whereType<String>()
                  .where((e) => e.isNotEmpty)
                  .join('. '),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ExcludeSemantics(
                  child: Row(children: [
                    if (image != null && image.scheme == 'https') ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(image.toString(),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(width: 56)),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((p.sponsorLabel ?? '').isEmpty ? 'Promotion' : p.sponsorLabel!,
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        Text(p.title!, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if ((p.description ?? '').isNotEmpty)
                          Text(p.description!,
                              style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text((p.ctaText ?? '').isEmpty ? 'Open' : p.ctaText!,
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
