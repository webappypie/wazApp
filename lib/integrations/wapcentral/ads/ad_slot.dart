// lib/integrations/wapcentral/ads/ad_slot.dart
//
// An ad placement. Renders nothing (zero height) when ads are off, unconfigured, offline or on no-fill, so content
// never shifts for an empty slot; spacing appears only once an ad has actually loaded.
//
// Approved placements: `home_native` (Home) and `saved_banner` (Saved). Never place a slot in the Private Folder,
// the viewer, the editors, the permission setup, Settings or next to a destructive action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wap_ads_sdk/wap_ads.dart';

import 'ads_controller.dart';

enum AdSlotFormat { banner, native }

abstract final class AdPlacements {
  static const homeNative = 'home_native';
  static const savedBanner = 'saved_banner';
}

class AdSlot extends ConsumerStatefulWidget {
  const AdSlot({
    super.key,
    required this.placementKey,
    this.format = AdSlotFormat.native,
    this.padding = EdgeInsets.zero,
  });

  final String placementKey;
  final AdSlotFormat format;

  /// Applied only after an ad loads.
  final EdgeInsets padding;

  @override
  ConsumerState<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends ConsumerState<AdSlot> {
  bool _loaded = false;

  void _onLoaded() {
    if (mounted && !_loaded) setState(() => _loaded = true);
  }

  void _onFailed(String _) {
    if (mounted && _loaded) setState(() => _loaded = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adsControllerProvider)) return const SizedBox.shrink();
    final ad = widget.format == AdSlotFormat.banner
        ? WapAds.banner(placementKey: widget.placementKey, onLoaded: _onLoaded, onFailed: _onFailed)
        : WapAds.native(placementKey: widget.placementKey, onLoaded: _onLoaded, onFailed: _onFailed);
    return Padding(padding: _loaded ? widget.padding : EdgeInsets.zero, child: ad);
  }
}
