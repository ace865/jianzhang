import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  await (FontLoader(
    'LedgerSerif',
  )..addFont(rootBundle.load('assets/fonts/NotoSerifSC.ttf'))).load();
  // Only test rendering uses this local font; release uses the platform's sans.
  final sans = File('C:/Windows/Fonts/msyh.ttc');
  await (FontLoader('Roboto')..addFont(
        await sans.exists()
            ? Future.value(ByteData.sublistView(await sans.readAsBytes()))
            : rootBundle.load('assets/fonts/NotoSerifSC.ttf'),
      ))
      .load();
  await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      ))
      .load();
}
