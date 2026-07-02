import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/ui/track/track_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpTrackScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: TrackScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Driftの監視ストリームのdispose時ゼロ秒タイマーを処理させてから終了する。
  Future<void> flushPendingTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('タグが無い場合はComposerにタグ追加ボタンが表示されない', (tester) async {
    await pumpTrackScreen(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('タグを追加'), findsNothing);

    await flushPendingTimers(tester);
  });

  testWidgets('タグを作成するとComposerにタグ追加ボタンが表示される', (tester) async {
    await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await pumpTrackScreen(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('タグを追加'), findsOneWidget);

    await flushPendingTimers(tester);
  });

  testWidgets('体調のみで記録を作成できる', (tester) async {
    await pumpTrackScreen(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.pumpAndSettle();

    final all = await db.recordsDao.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.value, 0);
    expect(all.single.comment, isNull);
    expect(all.single.tags, isEmpty);

    await flushPendingTimers(tester);
  });

  testWidgets('体調・タグ・コメント付きで記録を作成できる', (tester) async {
    await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await pumpTrackScreen(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('悪い'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('タグを追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('頭痛').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '朝から頭が重い');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.pumpAndSettle();

    final all = await db.recordsDao.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.value, -1);
    expect(all.single.comment, '朝から頭が重い');
    expect(all.single.tags, hasLength(1));
    expect(all.single.tags.single.name, '頭痛');

    await flushPendingTimers(tester);
  });

  testWidgets('タイムラインの記録を長押しして編集できる', (tester) async {
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: -1,
      comment: '元コメント',
    );
    await pumpTrackScreen(tester);

    await tester.longPress(find.text('元コメント'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '編集後コメント');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.pumpAndSettle();

    final all = await db.recordsDao.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.comment, '編集後コメント');

    await flushPendingTimers(tester);
  });

  testWidgets('タイムラインの記録を長押しして削除できる', (tester) async {
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 1,
      comment: '消えるコメント',
    );
    await pumpTrackScreen(tester);

    await tester.longPress(find.text('消えるコメント'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();

    final all = await db.recordsDao.watchAll().first;
    expect(all, isEmpty);

    await flushPendingTimers(tester);
  });
}
