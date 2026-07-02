import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/ui/app.dart';

/// plan.md §7 手動QAチェックリスト 8番:
/// 「Settings の全削除後、全画面が空状態表示になりクラッシュしない」を検証する。
void main() {
  Future<void> flushPendingTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('全削除後、各画面が空状態表示になりクラッシュしない', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final tagId = await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: -1,
      comment: '削除前のコメント',
      tagIds: [tagId],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const SelfTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 削除前: データが表示されていることを確認する。
    expect(find.text('削除前のコメント'), findsOneWidget);

    await goTo(tester, 'Tags');
    expect(find.text('頭痛'), findsOneWidget);

    await goTo(tester, 'Settings');
    await tester.tap(find.text('データを全て削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全て削除する'));
    await tester.pumpAndSettle();

    expect(find.text('全てのデータを削除しました。'), findsOneWidget);

    // 削除後: 例外を投げずに各画面が空状態表示に切り替わることを確認する。
    await goTo(tester, 'Track');
    expect(find.text('削除前のコメント'), findsNothing);
    expect(find.text('まだ記録がありません。'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await goTo(tester, 'Tags');
    expect(find.text('頭痛'), findsNothing);
    expect(find.text('タグがまだありません。右下の + から追加できます。'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await goTo(tester, 'Calendar');
    expect(find.text('データ無し'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await goTo(tester, 'Analysis');
    expect(find.text('記録がまだありません。Trackで記録を作成してみましょう。'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await flushPendingTimers(tester);
  });
}
