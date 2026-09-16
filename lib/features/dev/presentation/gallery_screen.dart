// lib/features/dev/presentation/gallery_screen.dart
//
// Component gallery — DEBUG ONLY. Route: /dev/gallery
// Renders every Phase 1 component in both light and dark themes side-by-side.
// This route MUST NOT be accessible in release builds (guarded in router).
//
// Definition of done check: gallery renders all components without errors
// on a real device in both themes.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/widgets/action_widgets.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/data_widgets.dart';
import '../../../core/widgets/filter_chip.dart';
import '../../../core/widgets/media_tiles.dart';
import '../../../core/widgets/monetisation_widgets.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/state_widgets.dart';

/// Returns a placeholder 1×1 transparent image for gallery thumbnails.
final _placeholderImage = MemoryImage(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
    0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
    0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND chunk
    0x44, 0xAE, 0x42, 0x60, 0x82,
  ]),
);

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _searchController = TextEditingController();
  int _selectedChip = 0;
  bool _itemSelected = false;
  bool _showBothThemes = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      // Gallery is debug only — this assertion fires if somehow reached in release.
      return true;
    }());

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Component Gallery'),
        actions: [
          Switch(
            value: _showBothThemes,
            onChanged: (v) => setState(() => _showBothThemes = v),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        children: [
          if (_showBothThemes)
            _SideBySideSection(
              title: 'Buttons',
              lightChild: _ButtonsDemo(),
              darkChild: _themed(Brightness.dark, _ButtonsDemo()),
            )
          else
            _Section(title: 'Buttons', child: _ButtonsDemo()),

          if (_showBothThemes)
            _SideBySideSection(
              title: 'StorageCard',
              lightChild: _StorageCardDemo(),
              darkChild: _themed(Brightness.dark, _StorageCardDemo()),
            )
          else
            _Section(title: 'StorageCard', child: _StorageCardDemo()),

          if (_showBothThemes)
            _SideBySideSection(
              title: 'StatCard & CategoryCard',
              lightChild: _CardRowDemo(),
              darkChild: _themed(Brightness.dark, _CardRowDemo()),
            )
          else
            _Section(title: 'StatCard & CategoryCard', child: _CardRowDemo()),

          _Section(title: 'Filter Chips', child: FilterChipRow(
            options: const ['All', 'Images', 'Videos', 'Audio'],
            selectedIndex: _selectedChip,
            onSelected: (i) => setState(() => _selectedChip = i),
          )),

          _Section(title: 'Search Field', child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
            child: SearchField(controller: _searchController, placeholder: 'Search media'),
          )),

          if (_showBothThemes)
            _SideBySideSection(
              title: 'MediaTile (grid)',
              lightChild: _MediaTileDemo(selected: _itemSelected, onTap: () => setState(() => _itemSelected = !_itemSelected)),
              darkChild: _themed(Brightness.dark, _MediaTileDemo(selected: _itemSelected, onTap: () => setState(() => _itemSelected = !_itemSelected))),
            )
          else
            _Section(title: 'MediaTile (grid)', child: _MediaTileDemo(selected: _itemSelected, onTap: () => setState(() => _itemSelected = !_itemSelected))),

          _Section(title: 'MediaListRow', child: MediaListRow(
            thumbnailProvider: _placeholderImage,
            title: 'IMG_20240315_142301.jpg',
            subtitle: '3.2 MB • 15 Mar 2024',
            isSelected: false,
            onTap: () {},
            onLongPress: () {},
          )),

          if (_showBothThemes)
            _SideBySideSection(
              title: 'EmptyState',
              lightChild: _EmptyDemo(),
              darkChild: _themed(Brightness.dark, _EmptyDemo()),
            )
          else
            _Section(title: 'EmptyState', child: _EmptyDemo()),

          _Section(title: 'ErrorState', child: ErrorState(
            message: 'We couldn\'t access this folder. Update media permissions to continue scanning.',
            onRetry: () {},
          )),

          _Section(title: 'Skeleton Loaders', child: SizedBox(
            height: 200,
            child: SkeletonListLoader(itemCount: 3),
          )),

          _Section(title: 'Skeleton Grid', child: SizedBox(
            height: 180,
            child: SkeletonGridLoader(crossAxisCount: 4, itemCount: 8),
          )),

          if (_showBothThemes)
            _SideBySideSection(
              title: 'ProgressRing',
              lightChild: _ProgressRingDemo(),
              darkChild: _themed(Brightness.dark, _ProgressRingDemo()),
            )
          else
            _Section(title: 'ProgressRing', child: _ProgressRingDemo()),

          _Section(title: 'AppProgressBar', child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
            child: Column(children: [
              AppProgressBar(fraction: 0.72, semanticLabel: '72% used'),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(fraction: 0.35, color: kColorSuccess),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(fraction: 0.9, color: kColorDestructive),
            ]),
          )),

          _Section(title: 'SimpleBarChart', child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
            child: SimpleBarChart(bars: const [
              ('Jan', 1.2), ('Feb', 2.4), ('Mar', 1.8), ('Apr', 3.1),
              ('May', 2.6), ('Jun', 4.0), ('Jul', 3.5),
            ]),
          )),

          _Section(title: 'SectionHeader', child: SectionHeader(
            label: 'Cleanup Opportunities',
            action: TextButton(onPressed: () {}, child: const Text('See all')),
          )),

          _Section(title: 'BottomActionBar (preview)', child: BottomActionBar(
            selectionCount: 3,
            selectionSizeLabel: '3 items • 450 MB',
            onMove: () {},
            onCopy: () {},
            onProtect: () {},
            onDelete: () {},
          )),

          _Section(title: 'NativeAdContainer (no-op in dev)', child: Column(children: [
            const NativeAdContainer(minContentItemsAbove: 15),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
              child: Text('↑ No space rendered (ads off by default in tests/dev)',
                  style: AppTextStyles.bodySmall),
            ),
          ])),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _themed(Brightness brightness, Widget child) {
    return Theme(
      data: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      child: Builder(builder: (_) => child),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo sub-widgets
// ---------------------------------------------------------------------------

class _ButtonsDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Column(
        children: [
          PrimaryButton(label: 'Review Cleanup', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(label: 'Loading…', onPressed: null, isLoading: true),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Cancel', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Delete 12 items', onPressed: () {}, isDestructive: true),
        ],
      ),
    );
  }
}

class _StorageCardDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: StorageCard(
        totalLabel: '18.4 GB',
        recoverableLabel: '4.2 GB',
        deltaLabel: '+780 MB this month',
        ctaLabel: 'Review Cleanup',
        onCta: () {},
      ),
    );
  }
}

class _CardRowDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: Column(children: [
        Row(children: [
          Expanded(child: StatCard(label: 'Files indexed', value: '12,481', icon: Icons.folder_outlined)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: StatCard(label: 'Space used', value: '18.4 GB', icon: Icons.storage_outlined)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        CategoryCard(
          icon: Icons.copy_all_outlined,
          title: 'Exact Duplicates',
          subtitle: '342 files • 1.8 GB',
          onTap: () {},
        ),
      ]),
    );
  }
}

class _MediaTileDemo extends StatelessWidget {
  const _MediaTileDemo({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      child: SizedBox(
        height: 100,
        child: Row(children: [
          SizedBox(
            width: 100,
            child: MediaTile(
              thumbnailProvider: _placeholderImage,
              isSelected: selected,
              onTap: onTap,
              onLongPress: () {},
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: MediaTile(
              thumbnailProvider: _placeholderImage,
              isSelected: false,
              isVideo: true,
              durationLabel: '05:42',
              onTap: () {},
              onLongPress: () {},
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: MediaTile(
              thumbnailProvider: _placeholderImage,
              isSelected: false,
              isProtected: true,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.check_circle_outline,
      title: 'No duplicates found',
      body: 'Your library looks clean. We\'ll check again during the next scan.',
    );
  }
}

class _ProgressRingDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ProgressRing(score: 82, label: 'Good'),
        ProgressRing(score: 54, label: 'Moderate'),
        ProgressRing(score: 21, label: 'High'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper layout widgets
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding, AppSpacing.lg, AppSpacing.pagePadding, AppSpacing.sm,
          ),
          child: Text(title, style: AppTextStyles.titleSmall),
        ),
        child,
        const Divider(height: AppSpacing.lg),
      ],
    );
  }
}

class _SideBySideSection extends StatelessWidget {
  const _SideBySideSection({
    required this.title,
    required this.lightChild,
    required this.darkChild,
  });
  final String title;
  final Widget lightChild;
  final Widget darkChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding, AppSpacing.lg, AppSpacing.pagePadding, AppSpacing.sm,
          ),
          child: Text(title, style: AppTextStyles.titleSmall),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: AppTheme.light().colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Theme(data: AppTheme.light(), child: lightChild),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Container(
                  color: AppTheme.dark().colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Theme(data: AppTheme.dark(), child: darkChild),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: AppSpacing.lg),
      ],
    );
  }
}
