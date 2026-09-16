// lib/core/widgets/filter_chip.dart
//
// AppFilterChip — horizontal scrollable filter chips used in category screens.
// Named differently from Material's FilterChip to avoid symbol clashes.

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// A single selectable filter chip.
///
/// Accessibility: label is the semantic text. Colour alone never conveys state —
/// selected state also uses a checkmark icon (REQ-SET-03).
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? label,
      selected: selected,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        avatar: selected ? Icon(Icons.check, size: 16, color: scheme.onPrimaryContainer) : null,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        showCheckmark: false, // we use avatar instead for design consistency
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
    );
  }
}

/// A row of [AppFilterChip]s in a horizontal scroll view.
/// Used in category screen filter bars.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.padding,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.xs),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            AppFilterChip(
              label: options[i],
              selected: selectedIndex == i,
              onSelected: (_) => onSelected(i),
            ),
            if (i < options.length - 1) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
