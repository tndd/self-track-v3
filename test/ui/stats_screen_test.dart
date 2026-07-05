import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/ui/stats/stats_screen.dart';

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

  testWidgets('記録が無い場合は空状態メッセージを表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('記録がまだありません。Trackで記録を作成してみましょう。'), findsOneWidget);

    await flushPendingTimers(tester);
  });

  testWidgets('タグが無い場合は行動×症状の関連が案内文になる', (tester) async {
    await db.recordsDao.createRecord(timestamp: DateTime.now(), value: 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('直近30日の体調スコア推移'), findsOneWidget);
    expect(find.text('イベントロック平均'), findsOneWidget);
    expect(find.text('タグがまだありません。'), findsOneWidget);
    expect(
      find.text('「症状」グループのタグと、それ以外のグループのタグが両方登録されると表示されます。'),
      findsOneWidget,
    );

    await flushPendingTimers(tester);
  });

  testWidgets('タグを選ぶとイベントロック平均グラフが描画される', (tester) async {
    final tagId = await db.tagsDao.createTag(name: 'コーヒー', group: '行動');
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 1,
      tagIds: [tagId],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('コーヒー'));
    await tester.pumpAndSettle();

    expect(find.textContaining('発生回数: 1回'), findsOneWidget);

    await flushPendingTimers(tester);
  });

  testWidgets('行動タグと症状タグが揃うとリフト値と発生回数不足の表示が出る', (tester) async {
    final coffeeId = await db.tagsDao.createTag(name: 'コーヒー', group: '行動');
    final headacheId = await db.tagsDao.createTag(name: '頭痛', group: '症状');

    // コーヒー→頭痛が3回以上共起し、閾値を満たすようにする。
    for (var i = 0; i < 4; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      await db.recordsDao.createRecord(
        timestamp: DateTime(day.year, day.month, day.day, 9),
        value: 0,
        tagIds: [coffeeId],
      );
      await db.recordsDao.createRecord(
        timestamp: DateTime(day.year, day.month, day.day, 10),
        value: -1,
        tagIds: [headacheId],
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('コーヒー → 頭痛'), findsOneWidget);
    expect(find.textContaining('リフト 1.00倍'), findsOneWidget);
    expect(find.text('データ不足'), findsNothing);

    await flushPendingTimers(tester);
  });

  testWidgets('発生回数が閾値未満の組はデータ不足と表示される', (tester) async {
    final coffeeId = await db.tagsDao.createTag(name: 'コーヒー', group: '行動');
    final headacheId = await db.tagsDao.createTag(name: '頭痛', group: '症状');

    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 0,
      tagIds: [coffeeId],
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      value: -1,
      tagIds: [headacheId],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('コーヒー → 頭痛'), findsOneWidget);
    expect(find.text('データ不足'), findsOneWidget);

    await flushPendingTimers(tester);
  });

  testWidgets('アーカイブ済みタグも統計の対象に残り続ける（design.md §5.4）', (tester) async {
    final coffeeId = await db.tagsDao.createTag(name: 'コーヒー', group: '行動');
    await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 1,
      tagIds: [coffeeId],
    );

    await db.tagsDao.archiveTag(coffeeId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // アーカイブしてもイベントロック平均の選択チップと
    // 行動×症状ペアの両方に残る（旧不具合: 統計から消えていた）。
    expect(find.widgetWithText(ChoiceChip, 'コーヒー'), findsOneWidget);
    expect(find.text('コーヒー → 頭痛'), findsOneWidget);

    await flushPendingTimers(tester);
  });

  testWidgets('イベントロック平均のタグは再タップで選択解除できる', (tester) async {
    final tagId = await db.tagsDao.createTag(name: 'コーヒー', group: '行動');
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 1,
      tagIds: [tagId],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('コーヒー'));
    await tester.pumpAndSettle();
    expect(find.textContaining('発生回数'), findsOneWidget);

    await tester.tap(find.text('コーヒー'));
    await tester.pumpAndSettle();
    expect(find.textContaining('発生回数'), findsNothing);

    await flushPendingTimers(tester);
  });
}
