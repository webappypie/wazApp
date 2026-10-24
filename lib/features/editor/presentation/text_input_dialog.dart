// lib/features/editor/presentation/text_input_dialog.dart
//
// Text entry dialog that owns (and disposes) its controller with the dialog's own
// lifecycle, so the closing animation never touches a disposed controller.

import 'package:flutter/material.dart';

class TextInputDialog extends StatefulWidget {
  const TextInputDialog({super.key, required this.title, this.initial = '', this.maxLength = 200});

  final String title;
  final String initial;
  final int maxLength;

  static Future<String?> show(BuildContext context, {required String title, String initial = ''}) =>
      showDialog<String>(context: context, builder: (_) => TextInputDialog(title: title, initial: initial));

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        minLines: 1,
        maxLines: 5,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Type in English or हिन्दी'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Done')),
      ],
    );
  }
}
