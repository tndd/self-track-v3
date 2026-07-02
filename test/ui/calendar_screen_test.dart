import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/data/database.dart';
import 'package:self_track_v3/providers/database_providers.dart';
import 'package:self_track_v3/providers/navigation_providers.dart';
import 'package:self_track_v3/providers/track_providers.dart';
import 'package:self_track_v3/ui/app.dart';
import 'package:self_track_v3/ui/calendar/calendar_screen.dart';

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

  testWidgets('月移動、今月の割合、7日間の傾向が実データから描画される', (tester) async {
    final now = DateTime.now();
    final thisMonthDay = DateTime(now.year, now.month, 10, 9);
    await db.recordsDao.createRecord(timestamp: thisMonthDay, value: 2);
    await db.recordsDao.createRecord(
      timestamp: DateTime(now.year, now.month, 11, 9),
      value: -2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final monthLabel = '${now.year}年${now.month}月';
    expect(find.text(monthLabel), findsOneWidget);
    expect(find.text('今月の割合'), findsOneWidget);
    expect(find.text('7日間の傾向'), findsOneWidget);
    // 記録の無い日は空白（今月平均の"-"とは別に、日次データ無しを示す）。
    expect(find.text('データ無し'), findsNothing);
    // 記録がある日（10日・11日）だけが色付きドット(CircleAvatar)で表示され、
    // それ以外の日は数字のみの空白セルになる。
    expect(find.byType(CircleAvatar), findsNWidgets(2));

    // 前の月に移動すると見出しが変わる
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    expect(find.text('${prevMonth.year}年${prevMonth.month}月'), findsOneWidget);

    await flushPendingTimers(tester);
  });

  testWidgets('日付セルをタップするとTrack画面のその日付に遷移する', (tester) async {
    final now = DateTime.now();
    final targetDay = DateTime(now.year, now.month, 5);
    await db.recordsDao.createRecord(
      timestamp: DateTime(targetDay.year, targetDay.month, targetDay.day, 9),
      value: 1,
    );

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(container.read(currentDestinationProvider), AppDestination.track);
    final selectedDate = container.read(selectedDateProvider);
    expect(selectedDate, DateTime(targetDay.year, targetDay.month, targetDay.day));

    await flushPendingTimers(tester);
  });
}
