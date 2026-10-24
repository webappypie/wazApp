// Loads the bundled OFL fonts into the test engine so text is shaped with real glyphs.

import 'dart:io';

import 'package:flutter/services.dart';

const _families = <String, List<String>>{
  'Hind': ['Hind-Regular.ttf', 'Hind-Bold.ttf'],
  'TiroDevanagariHindi': ['TiroDevanagariHindi-Regular.ttf'],
  'Kalam': ['Kalam-Regular.ttf', 'Kalam-Bold.ttf'],
  'RozhaOne': ['RozhaOne-Regular.ttf'],
  'Poppins': ['Poppins-SemiBold.ttf'],
  'Pacifico': ['Pacifico-Regular.ttf'],
};

bool _loaded = false;

Future<void> loadBundledFonts() async {
  if (_loaded) return;
  for (final e in _families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  _loaded = true;
}
