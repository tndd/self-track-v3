import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/ui/tags/tags_screen.dart';

void main() {
  testWidgets('タグの追加→編集→アーカイブ→解除が一通り動く', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TagsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('タグがまだありません。右下の + から追加できます。'), findsOneWidget);

    // 追加
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '頭痛');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'グループ（例: 薬, サプリ, 症状）'),
      '症状',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('頭痛'), findsOneWidget);
    expect(find.text('症状'), findsOneWidget);

    // 編集
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名前'), 'めまい');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('めまい'), findsOneWidget);
    expect(find.text('頭痛'), findsNothing);

    // アーカイブ（タップで即座に選択候補から外れ、下部の折りたたみに移動する）
    await tester.tap(find.byIcon(Icons.archive_outlined));
    await tester.pumpAndSettle();

    expect(find.text('アーカイブ済み（1）'), findsOneWidget);
    await tester.tap(find.text('アーカイブ済み（1）'));
    await tester.pumpAndSettle();
    expect(find.text('めまい'), findsOneWidget);

    // アーカイブ解除
    await tester.tap(find.byIcon(Icons.unarchive_outlined));
    await tester.pumpAndSettle();

    expect(find.text('アーカイブ済み（1）'), findsNothing);
    expect(find.text('めまい'), findsOneWidget);

    // Driftの監視ストリームはdispose時にゼロ秒タイマーを予約するため、
    // テスト終了前に明示的にツリーを破棄し、フェイクタイマーを進めて
    // そのタイマーを処理させておく。そうしないと flutter_test の
    // "pending timer" チェックに引っかかる。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('同名タグを追加しようとするとエラーメッセージが表示され、重複登録されない', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TagsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> addTag(String name, String group) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '名前'), name);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'グループ（例: 薬, サプリ, 症状）'),
        group,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
    }

    await addTag('頭痛', '症状');
    expect(find.text('頭痛'), findsOneWidget);

    await addTag('頭痛', '症状');
    expect(find.textContaining('既に存在'), findsOneWidget);

    final tags = await db.select(db.tags).get();
    expect(tags, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('色スウォッチ付きでタグを作成し、編集で自動配色に戻せる', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TagsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 赤（index 1）を選んで作成。
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '頭痛');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'グループ（例: 薬, サプリ, 症状）'),
      '症状',
    );
    await tester.tap(find.byKey(const ValueKey('color-swatch-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 画面側のallTagsProviderと同じwatchAll()ストリームを購読すると、
    // driftの共有ストリームへの.firstキャンセルが「Cannot add event while
    // adding stream」を誘発しテストが完了しなくなるため、ワンショットで読む。
    var tags = await db.select(db.tags).get();
    expect(tags.single.colorIndex, 1);

    // 編集で「自動」に戻すとnullになる。
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-auto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    tags = await db.select(db.tags).get();
    expect(tags.single.colorIndex, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
