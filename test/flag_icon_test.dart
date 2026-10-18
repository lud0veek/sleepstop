import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_stop/ui/widgets/flag_icon.dart';

void main() {
  testWidgets('FlagIcon lays out with a visible size and 3 colour bands', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(children: [FlagIcon(code: 'fr', width: 20)]),
        ),
      ),
    );
    final size = tester.getSize(find.byType(FlagIcon));
    expect(size.width, 20);
    expect(size.height, closeTo(13.3, 0.5));
    final bands = find.descendant(
      of: find.byType(FlagIcon),
      matching: find.byType(ColoredBox),
    );
    expect(bands, findsNWidgets(3));
    for (final band in tester.widgetList<ColoredBox>(bands)) {
      final bandSize = tester.getSize(find.byWidget(band));
      expect(bandSize.width, greaterThan(0));
      expect(bandSize.height, greaterThan(0));
    }
  });
}
