import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/providers/track_providers.dart';
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

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
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

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
    expect(all, hasLength(1));
    expect(all.single.value, -1);
    expect(all.single.comment, '朝から頭が重い');
    expect(all.single.tags, hasLength(1));
    expect(all.single.tags.single.name, '頭痛');

    await flushPendingTimers(tester);
  });

  testWidgets('複数日の記録が日付ヘッダ付きで表示され、最新が最下部に来る', (tester) async {
    final now = DateTime.now();
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    await db.recordsDao.createRecord(
      timestamp: threeDaysAgo,
      value: 0,
      comment: '3日前のコメント',
    );
    await db.recordsDao.createRecord(
      timestamp: now,
      value: 1,
      comment: '今日のコメント',
    );
    await pumpTrackScreen(tester);

    expect(find.text('今日のコメント'), findsOneWidget);
    expect(find.text('3日前のコメント'), findsOneWidget);

    String headerLabel(DateTime d) =>
        '${d.month}月${d.day}日 ${'月火水木金土日'[d.weekday - 1]}曜';
    expect(find.text(headerLabel(now)), findsOneWidget);
    expect(find.text(headerLabel(threeDaysAgo)), findsOneWidget);

    // チャット式: 新しい記録ほど画面の下（dyが大きい）に表示される。
    final todayDy = tester.getCenter(find.text('今日のコメント')).dy;
    final pastDy = tester.getCenter(find.text('3日前のコメント')).dy;
    expect(todayDy, greaterThan(pastDy));

    await flushPendingTimers(tester);
  });

  testWidgets('初期ウィンドウ（14日）より古い記録も遡って読み込まれ、終端で読み込み表示が消える',
      (tester) async {
    await db.recordsDao.createRecord(
      timestamp: DateTime.now().subtract(const Duration(days: 30)),
      value: -1,
      comment: '30日前のコメント',
    );
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 0,
      comment: '今日のコメント',
    );
    await pumpTrackScreen(tester);

    // コンテンツが画面に収まる場合は最上部が常に見えているため、
    // 位置リスナー経由で最古日まで自動的にウィンドウが広がる。
    expect(find.text('30日前のコメント'), findsOneWidget);
    // 終端に達したので読み込み中インジケータは表示されない。
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await flushPendingTimers(tester);
  });

  testWidgets('日付ジャンプ要求でウィンドウが対象日まで広がる', (tester) async {
    final target = DateTime.now().subtract(const Duration(days: 60));
    await db.recordsDao.createRecord(
      timestamp: target,
      value: 0,
      comment: '60日前のコメント',
    );

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TrackScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final targetDay = DateTime(target.year, target.month, target.day);
    container.read(selectedDateProvider.notifier).state = targetDay;
    container.read(dateJumpSeqProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(
      container.read(timelineWindowStartProvider).isAfter(targetDay),
      isFalse,
    );
    expect(find.text('60日前のコメント'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await flushPendingTimers(tester);
  });

  testWidgets('コメント欄をタップしてもStatus入力は展開されない（+ボタンでのみ展開）', (tester) async {
    await pumpTrackScreen(tester);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsNothing);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);

    await flushPendingTimers(tester);
  });

  testWidgets('パネル外（scrim）をタップするとComposerが閉じる', (tester) async {
    await pumpTrackScreen(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('composer-scrim')));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsNothing);

    await flushPendingTimers(tester);
  });

  testWidgets('全画面ボタンからタグ選択を開き、完了で選択が反映される', (tester) async {
    await db.tagsDao.createTag(name: '頭痛', group: '症状');
    await pumpTrackScreen(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('タグを追加'));
    await tester.pumpAndSettle();

    // タグゾーン展開中はボタンがゴースト表示「タグ表示中」になる。
    expect(find.text('タグ表示中'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.open_in_full));
    await tester.pumpAndSettle();
    expect(find.text('完了'), findsOneWidget);

    await tester.tap(find.text('頭痛').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    // ダイアログが閉じ、選択済みタグとしてComposerに表示される。
    expect(find.text('完了'), findsNothing);
    expect(find.text('頭痛'), findsWidgets);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.pumpAndSettle();

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
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

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
    expect(all, hasLength(1));
    expect(all.single.comment, '編集後コメント');

    await flushPendingTimers(tester);
  });

  testWidgets('アーカイブ済みタグ付きレコードを編集すると、そのタグがチップとして表示される', (tester) async {
    final tagId = await db.tagsDao.createTag(name: '旧タグ', group: '症状');
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 0,
      comment: 'アーカイブタグ付き',
      tagIds: [tagId],
    );
    await db.tagsDao.archiveTag(tagId);
    await pumpTrackScreen(tester);

    await tester.longPress(find.text('アーカイブタグ付き'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, '旧タグ'), findsOneWidget);

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

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
    expect(all, isEmpty);

    await flushPendingTimers(tester);
  });

  testWidgets('編集中にscrimをタップすると編集が破棄され、次の送信は新規作成になる', (tester) async {
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
    expect(find.text('記録を編集中'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('composer-scrim')));
    await tester.pumpAndSettle();
    expect(find.text('記録を編集中'), findsNothing);

    // 編集状態が残っていると、新規のつもりの送信が元レコードを
    // 黙って上書きしてしまう（旧不具合）。新規作成になることを確認する。
    await tester.enterText(find.byType(TextField), '新しいコメント');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.pumpAndSettle();

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
    expect(all, hasLength(2));
    expect(
      all.map((r) => r.comment),
      containsAll(['元コメント', '新しいコメント']),
    );

    await flushPendingTimers(tester);
  });

  testWidgets('送信ボタンの素早い二度押しでもレコードは1件だけ作成される', (tester) async {
    await pumpTrackScreen(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '一度だけ');

    // 送信ボタンの二度押し。実行中は_submittingガード、送信完了後は
    // 「畳んだ状態かつ入力が空の送信を無視する」ガードで弾かれる。
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.pumpAndSettle();

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
    expect(all, hasLength(1));
    expect(all.single.comment, '一度だけ');

    await flushPendingTimers(tester);
  });

  testWidgets('アーカイブ済みタグ付きレコードを編集すると、チップ表示され取り外せる', (tester) async {
    final tagId = await db.tagsDao.createTag(name: '旧薬', group: '薬');
    await db.recordsDao.createRecord(
      timestamp: DateTime.now(),
      value: 0,
      comment: '服用メモ',
      tagIds: [tagId],
    );
    await db.tagsDao.archiveTag(tagId);
    await pumpTrackScreen(tester);

    await tester.longPress(find.text('服用メモ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    // アーカイブ済みタグは選択候補には出ないが、編集対象レコードに付いて
    // いる場合は選択中チップとして見え、取り外せる必要がある（旧不具合:
    // 見えないまま保存で再付与され、外す手段が無かった）。
    final chip = find.widgetWithText(InputChip, '旧薬');
    expect(chip, findsOneWidget);

    await tester.tap(
      find.descendant(of: chip, matching: find.byType(Icon)),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '旧薬'), findsNothing);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward));
    await tester.pumpAndSettle();

    final all =
        (await tester.runAsync(() => db.recordsDao.watchAll().first))!;
    expect(all.single.tags, isEmpty);

    await flushPendingTimers(tester);
  });
}
