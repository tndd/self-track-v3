import '../../domain/dates.dart';
import '../../domain/models.dart';

const kWeekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// タイムラインの日付見出し・ヘッダ直下の日付バーで共通に使う日付ラベル。
/// 両者はスクロールで重なった際に表示がピタリと一致する必要があるため、
/// 書式は必ずこの関数で一元化する。
String formatTimelineDayLabel(DateTime day) =>
    '${day.month}月${day.day}日 ${kWeekdayLabels[day.weekday - 1]}曜';

/// チャット式タイムライン（reverse:true のリスト）の1行を表すモデル。
/// index 0 が画面最下部（最新）、末尾が最上部（最古側）になる。
sealed class TimelineEntry {
  const TimelineEntry();
}

class TimelineRecordEntry extends TimelineEntry {
  const TimelineRecordEntry(this.record);

  final RecordWithTags record;
}

class TimelineDateHeaderEntry extends TimelineEntry {
  const TimelineDateHeaderEntry(this.day);

  final DateTime day;

  String get label => formatTimelineDayLabel(day);
}

/// さらに過去を読み込み中であることを示す行（リスト最上部に表示）。
class TimelineLoadingEntry extends TimelineEntry {
  const TimelineLoadingEntry();
}

/// 新しい順のレコード列から reverse:true ListView 用のエントリ列を組み立てる。
/// 日付が切り替わる位置（配列上で次に古い日に移る直前）と末尾に日付ヘッダを
/// 挿入すると、画面上では各日のレコード群の直上にヘッダが表示される。
/// 記録の無い日はヘッダ自体が生成されず自然にスキップされる。
List<TimelineEntry> buildTimelineEntries(
  List<RecordWithTags> descRecords, {
  required bool hasMore,
}) {
  final entries = <TimelineEntry>[];
  DateTime? currentDay;
  for (final record in descRecords) {
    final day = startOfDay(record.timestamp);
    if (currentDay != null && day != currentDay) {
      entries.add(TimelineDateHeaderEntry(currentDay));
    }
    currentDay = day;
    entries.add(TimelineRecordEntry(record));
  }
  if (currentDay != null) {
    entries.add(TimelineDateHeaderEntry(currentDay));
  }
  if (hasMore) {
    entries.add(const TimelineLoadingEntry());
  }
  return entries;
}
