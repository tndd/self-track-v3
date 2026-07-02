import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:self_track_v3/ui/app.dart';

void main() {
  testWidgets('5つの画面をハンバーガーメニューから切り替えられる', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SelfTrackApp()));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Track（M3で実装）'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    for (final destination in AppDestination.values) {
      expect(find.text(destination.label), findsWidgets);
    }

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    expect(find.text('Calendar（M5で実装）'), findsOneWidget);
  });
}
