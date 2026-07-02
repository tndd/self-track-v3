import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/ui/settings/settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> flushPendingTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  // SettingsScreenはどのストリームも監視していないため、DAOのwatch系メソッドを
  // テストから直接呼ぶと、ウィジェットツリー経由の既存購読が無く新規に
  // ストリームを開くことになる。flutter_testはテスト本体をFakeAsyncゾーンで
  // 実行しており、その新規購読が依存する実タイマー／マイクロタスクはフェイク
  // 時計を進めない限り解決しないため、素のawaitだけでは永久にハングする。
  // tester.runAsyncで実イベントループに逃がして読み出す。

  testWidgets('キャンセルすればデータは削除されない', (tester) async {
    final tagId = await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await db.recordsDao.createRecord(timestamp: DateTime.now(), value: 1, tagIds: [tagId]);

    await pumpSettingsScreen(tester);

    await tester.tap(find.text('データを全て削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    final records = await tester.runAsync(() => db.recordsDao.watchAll().first);
    final tags = await tester.runAsync(() => db.tagsDao.watchAll().first);
    expect(records, hasLength(1));
    expect(tags, hasLength(1));

    await flushPendingTimers(tester);
  });

  testWidgets('2段階の確認を経ると全データが削除される', (tester) async {
    final tagId = await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await db.recordsDao.createRecord(timestamp: DateTime.now(), value: 1, tagIds: [tagId]);

    await pumpSettingsScreen(tester);

    await tester.tap(find.text('データを全て削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全て削除する'));
    await tester.pumpAndSettle();

    final records = await tester.runAsync(() => db.recordsDao.watchAll().first);
    final tags = await tester.runAsync(() => db.tagsDao.watchAll().first);
    expect(records, isEmpty);
    expect(tags, isEmpty);
    expect(find.text('全てのデータを削除しました。'), findsOneWidget);

    await flushPendingTimers(tester);
  });
}
