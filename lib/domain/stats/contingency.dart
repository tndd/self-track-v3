import '../models.dart';

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

/// [records]全体から、[actionTagId]・[symptomTagId]それぞれのタグが
/// 付いた日の集合を求め、観測日（レコードが1件以上ある日）を母集団として
/// 2×2分割表を構築する。
ContingencyTable buildDayContingencyTable({
  required List<RecordWithTags> records,
  required String actionTagId,
  required String symptomTagId,
}) {
  final observedDays = <DateTime>{};
  final actionDays = <DateTime>{};
  final symptomDays = <DateTime>{};

  for (final record in records) {
    final day = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
    observedDays.add(day);
    if (record.tags.any((t) => t.id == actionTagId)) {
      actionDays.add(day);
    }
    if (record.tags.any((t) => t.id == symptomTagId)) {
      symptomDays.add(day);
    }
  }

  var a = 0, b = 0, c = 0, d = 0;
  for (final day in observedDays) {
    final hasAction = actionDays.contains(day);
    final hasSymptom = symptomDays.contains(day);
    if (hasAction && hasSymptom) {
      a++;
    } else if (hasAction) {
      b++;
    } else if (hasSymptom) {
      c++;
    } else {
      d++;
    }
  }

  return ContingencyTable(a: a, b: b, c: c, d: d);
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
