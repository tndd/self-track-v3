import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';

import 'package:self_track_v3/ui/app.dart';

void main() {
  testWidgets('5つの画面をハンバーガーメニューから切り替えられる', (WidgetTester tester) async {
    // Tags画面が実DBのプロバイダを参照するため、テストではインメモリDBに差し替える。
    // 差し替えないとdrift_flutterがpath_providerのプラットフォームチャンネルを
    // 呼び出し、テスト環境ではハンドラが無いためハングする。
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const SelfTrackApp(),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('コメントを書く...'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    for (final destination in AppDestination.values) {
      expect(find.text(destination.label), findsWidgets);
    }

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    expect(find.text('Calendar（M5で実装）'), findsOneWidget);

    // Driftの監視ストリームのdispose時ゼロ秒タイマーを処理させてから終了する。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
