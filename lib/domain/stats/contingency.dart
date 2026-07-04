import '../dates.dart';
import '../models.dart';

/// design.md・draft.mdの「基本的には'症状'がyになる想定」に基づき、
/// group名がこの値のタグをsymptom、それ以外をactionとして扱う。
/// 統計のy/x振り分けはdomain層の仕様であり、UI側はこの定数を参照する。
const kSymptomGroupName = '症状';

/// タグ×日の共起を表す2×2分割表。
///
/// |            | symptom日 | ¬symptom日 |
/// |:-----------|:---------:|:----------:|
/// | action日   |     a     |     b      |
/// | ¬action日  |     c     |     d      |
///
/// design.md §4.3・plan.md M6: v1.0では時間窓ではなく「日単位の共起」で
/// 集計する。「観測日」＝レコードが1件以上存在する日のみを対象とし、
/// アプリを開いていない（記録が無い）日は「actionが起きなかった」とは
/// 見なさない。
class ContingencyTable {
  const ContingencyTable({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
  });

  final int a;
  final int b;
  final int c;
  final int d;

  int get n => a + b + c + d;

  /// actionタグが観測された日数（a+b）。
  int get actionDayCount => a + b;

  /// symptomタグが観測された日数（a+c）。
  int get symptomDayCount => a + c;
}

/// [records]を1パス走査した「観測日の集合」と「タグごとの発生日の集合」。
/// 全action×symptomペアの分割表構築で共有し、ペアごとの全レコード再走査
/// （O(ペア数×レコード数)）を避けるための前計算。
class DayTagSets {
  const DayTagSets({required this.observedDays, required this.daysByTag});

  /// レコードが1件以上存在する日の集合（分割表の母集団）。
  final Set<DateTime> observedDays;

  /// タグID -> そのタグが付いたレコードが存在する日の集合。
  final Map<String, Set<DateTime>> daysByTag;
}

/// [records]全体を1回だけ走査して[DayTagSets]を構築する。
DayTagSets buildDayTagSets(List<RecordWithTags> records) {
  final observedDays = <DateTime>{};
  final daysByTag = <String, Set<DateTime>>{};

  for (final record in records) {
    final day = startOfDay(record.timestamp);
    observedDays.add(day);
    for (final tag in record.tags) {
      daysByTag.putIfAbsent(tag.id, () => {}).add(day);
    }
  }

  return DayTagSets(observedDays: observedDays, daysByTag: daysByTag);
}

/// 前計算済みの[sets]から、[actionTagId]×[symptomTagId]の2×2分割表を構築する。
/// 観測日（レコードが1件以上ある日）を母集団とする。
ContingencyTable buildContingencyFromSets({
  required DayTagSets sets,
  required String actionTagId,
  required String symptomTagId,
}) {
  final actionDays = sets.daysByTag[actionTagId] ?? const <DateTime>{};
  final symptomDays = sets.daysByTag[symptomTagId] ?? const <DateTime>{};

  final a = actionDays.intersection(symptomDays).length;
  final b = actionDays.length - a;
  final c = symptomDays.length - a;
  final d = sets.observedDays.length - a - b - c;

  return ContingencyTable(a: a, b: b, c: c, d: d);
}

/// [records]全体から、[actionTagId]・[symptomTagId]それぞれのタグが
/// 付いた日の集合を求め、観測日（レコードが1件以上ある日）を母集団として
/// 2×2分割表を構築する。
///
/// 複数ペアをまとめて計算する場合は[buildDayTagSets]を1回だけ実行して
/// [buildContingencyFromSets]を使うこと。
ContingencyTable buildDayContingencyTable({
  required List<RecordWithTags> records,
  required String actionTagId,
  required String symptomTagId,
}) {
  return buildContingencyFromSets(
    sets: buildDayTagSets(records),
    actionTagId: actionTagId,
    symptomTagId: symptomTagId,
  );
}

/// design.md §4.3・plan.md §6.4: オッズ比。分割表にゼロのセルがある場合は
/// Haldane補正（各セル+0.5）を適用する（Fisherの検定自体には補正を使わない）。
double oddsRatio(ContingencyTable table) {
  final hasZero = table.a == 0 || table.b == 0 || table.c == 0 || table.d == 0;
  final a = hasZero ? table.a + 0.5 : table.a.toDouble();
  final b = hasZero ? table.b + 0.5 : table.b.toDouble();
  final c = hasZero ? table.c + 0.5 : table.c.toDouble();
  final d = hasZero ? table.d + 0.5 : table.d.toDouble();
  return (a * d) / (b * c);
}

/// design.md §4.3: リフト値 = P(symptom日|action日) / P(symptom日)。
/// actionまたはsymptomの観測日が無い場合はnullを返す。
double? liftValue(ContingencyTable table) {
  final actionDays = table.actionDayCount;
  final symptomDays = table.symptomDayCount;
  if (actionDays == 0 || symptomDays == 0 || table.n == 0) return null;

  final pSymptomGivenAction = table.a / actionDays;
  final pSymptomOverall = symptomDays / table.n;
  if (pSymptomOverall == 0) return null;

  return pSymptomGivenAction / pSymptomOverall;
}
