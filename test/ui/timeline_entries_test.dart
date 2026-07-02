import 'package:flutter_test/flutter_test.dart';
import 'package:self_track_v3/domain/models.dart';
import 'package:self_track_v3/ui/track/timeline_entries.dart';

RecordWithTags record(String id, DateTime timestamp) => RecordWithTags(
      id: id,
      timestamp: timestamp,
      comment: null,
      value: 0,
      tags: const [],
    );

void main() {
  test('日付が変わる位置と末尾に日付ヘッダが挿入される', () {
    // 新しい順（reverse:true リストの index 0 = 画面最下部）。
    final entries = buildTimelineEntries([
      record('a', DateTime(2026, 7, 2, 14, 20)),
      record('b', DateTime(2026, 7, 2, 12, 5)),
      record('c', DateTime(2026, 7, 1, 9, 0)),
    ], hasMore: false);

    expect(entries, hasLength(5));
    expect((entries[0] as TimelineRecordEntry).record.id, 'a');
    expect((entries[1] as TimelineRecordEntry).record.id, 'b');
    expect((entries[2] as TimelineDateHeaderEntry).day, DateTime(2026, 7, 2));
    expect((entries[3] as TimelineRecordEntry).record.id, 'c');
    expect((entries[4] as TimelineDateHeaderEntry).day, DateTime(2026, 7, 1));
  });

  test('記録の無い日はヘッダが生成されずスキップされる', () {
    final entries = buildTimelineEntries([
      record('a', DateTime(2026, 7, 3, 8, 0)),
      record('b', DateTime(2026, 6, 30, 8, 0)), // 7/1・7/2は記録なし
    ], hasMore: false);

    final headers = entries.whereType<TimelineDateHeaderEntry>().toList();
    expect(headers.map((h) => h.day), [DateTime(2026, 7, 3), DateTime(2026, 6, 30)]);
  });

  test('空リストでは空、hasMore=trueなら末尾に読み込み中エントリが付く', () {
    expect(buildTimelineEntries(const [], hasMore: false), isEmpty);

    final entries = buildTimelineEntries([
      record('a', DateTime(2026, 7, 2, 8, 0)),
    ], hasMore: true);
    expect(entries.last, isA<TimelineLoadingEntry>());
  });

  test('日付ヘッダのラベルは「N月N日 曜」形式', () {
    // 2026-07-01は水曜日。
    final entry = buildTimelineEntries(
      [record('a', DateTime(2026, 7, 1, 8, 0))],
      hasMore: false,
    ).whereType<TimelineDateHeaderEntry>().single;
    expect(entry.label, '7月1日 水曜');
  });
}
