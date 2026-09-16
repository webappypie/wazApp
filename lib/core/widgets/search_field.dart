// lib/core/widgets/search_field.dart
//
// SearchField — standardised search input used in Home and Organize.

import 'package:flutter/material.dart';

import '../design/tokens.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.placeholder = 'Search',
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String placeholder;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: placeholder,
      textField: true,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(Icons.clear, color: scheme.onSurfaceVariant, size: 18),
                    onPressed: controller.clear,
                    tooltip: 'Clear search',
                  ),
          ),
        ),
      ),
    );
  }
}
