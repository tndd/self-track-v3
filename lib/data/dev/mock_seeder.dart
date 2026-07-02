import 'dart:math';

import 'package:drift/drift.dart';

import '../database.dart';

/// デバッグビルド専用のモックデータ生成器。
///
/// 開発用DB（self_track_v3_dev）が空のとき、[anchor]（既定は現在時刻）から
/// 遡って約180日分・800件以上のレコードを投入する。全画面のUI確認が
/// 目的のため、以下を意図的に作り込む:
///
/// - Calendar: 記録なしの日（約10%）と、午前のみ記録の日（約15%、
///   次レコードまで12時間超の間隔ができ減衰補間が発動する）
/// - Stats: 「コーヒー→頭痛」「低気圧→頭痛」の正の関連、
///   「ウォーキング→倦怠感」の負の関連が分割表で有意になる共起設計。
///   頭痛の日は70%の確率で2〜4時間後にロキソニン＋体調回復レコードを
///   置き、イベントロック平均で「悪化→服薬→回復」の谷が見えるようにする
/// - Tags: 6グループ・18タグ（うち3つはアーカイブ済み）
///
/// [seed]固定の擬似乱数で生成するため、同じseed・anchorなら結果は再現する。
class MockSeeder {
  MockSeeder(this.db, {int seed = 42, DateTime? anchor})
      : _random = Random(seed),
        _anchor = anchor ?? DateTime.now();

  final AppDatabase db;
  final Random _random;
  final DateTime _anchor;

  static const _daySpan = 180;

  /// tags・recordsが両方とも空の場合のみ投入する。投入したらtrueを返す。
  Future<bool> seedIfEmpty() async {
    final tagCount = await db.tags.count().getSingle();
    final recordCount = await db.records.count().getSingle();
    if (tagCount > 0 || recordCount > 0) return false;
    await seed();
    return true;
  }

  /// モックデータを生成して1トランザクションで一括投入する。
  Future<void> seed() async {
    final tags = _buildTags();
    final records = <RecordsCompanion>[];
    final links = <RecordTagsCompanion>[];

    var recordSeq = 0;
    final today = DateTime(_anchor.year, _anchor.month, _anchor.day);
    for (var offset = _daySpan - 1; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      recordSeq = _buildDay(day, offset, recordSeq, records, links);
    }

    // recordTagsのFKがrecordsを参照するため、この投入順を守ること。
    await db.batch((b) {
      b.insertAll(db.tags, tags);
      b.insertAll(db.records, records);
      b.insertAll(db.recordTags, links);
    });
  }

  // ---- タグ定義 ----------------------------------------------------------

  // Stats画面はgroup名「症状」のタグをsymptom、それ以外をactionとして扱う
  // （ui/stats/tag_pair_list.dart）。
  static const _tagDefs = [
    ('headache', '頭痛', '症状', false),
    ('fatigue', '倦怠感', '症状', false),
    ('stomachache', '腹痛', '症状', false),
    ('dizziness', 'めまい', '症状', false),
    ('stiff-shoulder', '肩こり', '症状', true),
    ('loxonin', 'ロキソニン', '薬', false),
    ('stomach-medicine', '胃薬', '薬', false),
    ('vitamin-d', 'ビタミンD', 'サプリ', false),
    ('magnesium', 'マグネシウム', 'サプリ', false),
    ('iron', '鉄分', 'サプリ', true),
    ('walking', 'ウォーキング', '運動', false),
    ('training', '筋トレ', '運動', false),
    ('stretch', 'ストレッチ', '運動', false),
    ('low-pressure', '低気圧', '環境', false),
    ('heat-wave', '猛暑', '環境', false),
    ('coffee', 'コーヒー', '食事', false),
    ('alcohol', '飲酒', '食事', false),
    ('eating-out', '外食', '食事', true),
  ];

  static String tagId(String key) => 'seed-tag-$key';

  List<TagsCompanion> _buildTags() {
    return [
      for (final (key, name, group, archived) in _tagDefs)
        TagsCompanion.insert(
          id: tagId(key),
          name: name,
          group: group,
          isArchived: Value(archived),
        ),
    ];
  }

  // ---- レコード生成 ------------------------------------------------------

  static const _comments = [
    '朝から頭が重い',
    '散歩したら少し楽になった',
    '特に変化なし',
    'よく眠れた気がする',
    '昼過ぎから調子が悪い',
    '薬を飲んだら落ち着いた',
    '天気が悪くてだるい',
    '仕事が忙しかった',
    '早めに休むことにする',
    '食後に胃がもたれる',
  ];

  /// 1日分のレコード・タグ紐付けを生成し、次のレコード連番を返す。
  int _buildDay(
    DateTime day,
    int dayOffset,
    int recordSeq,
    List<RecordsCompanion> records,
    List<RecordTagsCompanion> links,
  ) {
    // 約10%は記録なしの日（Calendarの空白セル・観測日から除外される日）。
    if (_random.nextDouble() < 0.10) return recordSeq;

    final isMorningOnly = _random.nextDouble() < 0.15;
    final times = _buildTimes(day, isMorningOnly);

    // 日単位の調子バイアス。日平均を±1側に寄せ、Calendarのドットが
    // 5段階（赤〜青）で色分けされる日を作る。
    final moodRoll = _random.nextDouble();
    final dayMood = moodRoll < 0.20 ? -1 : (moodRoll < 0.70 ? 0 : 1);

    // 日単位の共起フラグ。コーヒー・低気圧は頭痛を増やし、
    // ウォーキングは倦怠感を減らす方向に設計する。
    final coffeeDay = _random.nextDouble() < 0.35;
    final lowPressureDay = _random.nextDouble() < 0.20;
    final walkingDay = _random.nextDouble() < 0.30;
    var headacheProb = 0.14;
    if (coffeeDay) headacheProb += 0.41;
    if (lowPressureDay) headacheProb += 0.25;
    final headacheDay = _random.nextDouble() < min(headacheProb, 0.90);
    final fatigueDay = _random.nextDouble() < (walkingDay ? 0.05 : 0.15);

    final dayTags = List.generate(times.length, (_) => <String>{});
    final dayValues = List.generate(times.length, (_) => _drawValue(dayMood));

    if (headacheDay) {
      // 先頭レコードを頭痛＋不調にし、70%で2〜4時間後に服薬＋回復を置く。
      dayTags[0].add(tagId('headache'));
      dayValues[0] = _random.nextBool() ? -2 : -1;
      final reliefIndex = _indexAfter(times, times[0], hours: 2);
      if (reliefIndex != null && _random.nextDouble() < 0.70) {
        dayTags[reliefIndex].add(tagId('loxonin'));
        dayValues[reliefIndex] =
            min(1, dayValues[0] + 1 + _random.nextInt(2));
        for (var i = reliefIndex + 1; i < times.length; i++) {
          dayValues[i] = _random.nextInt(2); // 0 or +1 で回復基調
        }
      }
    }
    if (fatigueDay) {
      final i = _random.nextInt(times.length);
      dayTags[i].add(tagId('fatigue'));
      dayValues[i] = min(dayValues[i], -1);
    }
    if (coffeeDay) dayTags[0].add(tagId('coffee'));
    if (lowPressureDay) {
      dayTags[_random.nextInt(times.length)].add(tagId('low-pressure'));
    }
    if (walkingDay) {
      final i = _random.nextInt(times.length);
      dayTags[i].add(tagId('walking'));
      dayValues[i] = max(dayValues[i], 0);
    }

    // 日常ノイズ。value=0＋行動タグ（「普通の体調でその行動をした」）も含める。
    if (_random.nextDouble() < 0.50) dayTags[0].add(tagId('vitamin-d'));
    if (_random.nextDouble() < 0.10) dayTags[0].add(tagId('magnesium'));
    if (_random.nextDouble() < 0.10) {
      dayTags[times.length - 1].add(tagId('training'));
    }
    if (_random.nextDouble() < 0.12) {
      dayTags[times.length - 1].add(tagId('stretch'));
    }
    if (_random.nextDouble() < 0.15) {
      dayTags[times.length - 1].add(tagId('alcohol'));
    }
    if (_random.nextDouble() < 0.08) {
      final i = _random.nextInt(times.length);
      dayTags[i].add(tagId('stomach-medicine'));
      dayTags[i].add(tagId('stomachache'));
      dayValues[i] = min(dayValues[i], 0);
    }
    if (_random.nextDouble() < 0.05) {
      dayTags[_random.nextInt(times.length)].add(tagId('dizziness'));
    }
    if (day.month >= 7 && day.month <= 9 && _random.nextDouble() < 0.15) {
      dayTags[_random.nextInt(times.length)].add(tagId('heat-wave'));
    }
    // アーカイブ済みタグは90日より前の古い記録にのみ残す
    // （過去のログには出るが、現在の入力候補には出ない状態を再現）。
    if (dayOffset > 90) {
      if (_random.nextDouble() < 0.10) {
        dayTags[_random.nextInt(times.length)].add(tagId('stiff-shoulder'));
      }
      if (_random.nextDouble() < 0.10) dayTags[0].add(tagId('iron'));
      if (_random.nextDouble() < 0.10) {
        dayTags[times.length - 1].add(tagId('eating-out'));
      }
    }

    for (var i = 0; i < times.length; i++) {
      final id = 'seed-rec-${recordSeq.toString().padLeft(4, '0')}';
      recordSeq++;
      records.add(
        RecordsCompanion.insert(
          id: id,
          timestamp: times[i],
          comment: Value(
            _random.nextDouble() < 0.40
                ? _comments[_random.nextInt(_comments.length)]
                : null,
          ),
          value: Value(dayValues[i]),
          updatedAt: times[i],
        ),
      );
      for (final tag in dayTags[i]) {
        links.add(RecordTagsCompanion.insert(recordId: id, tagId: tag));
      }
    }
    return recordSeq;
  }

  /// その日のレコード時刻を昇順で生成する。午前のみの日は6:00〜9:00に
  /// 3件（翌日まで12時間超が空きCalendarの減衰補間が発動する）、
  /// 通常日は6:30〜22:30に4〜8件。
  List<DateTime> _buildTimes(DateTime day, bool isMorningOnly) {
    final count = isMorningOnly ? 3 : 4 + _random.nextInt(5);
    final (minMinute, maxMinute) = isMorningOnly ? (360, 540) : (390, 1350);
    final minutes = <int>{};
    while (minutes.length < count) {
      minutes.add(minMinute + _random.nextInt(maxMinute - minMinute));
    }
    return (minutes.toList()..sort())
        .map((m) => day.add(Duration(minutes: m)))
        .toList();
  }

  /// [base]から[hours]時間以上あとの最初のレコード位置を返す。無ければnull。
  int? _indexAfter(List<DateTime> times, DateTime base, {required int hours}) {
    final threshold = base.add(Duration(hours: hours));
    for (var i = 0; i < times.length; i++) {
      if (!times[i].isBefore(threshold)) return i;
    }
    return null;
  }

  /// 体調値（DB値 -2〜2）を現実的な分布で抽選する。0が最頻で、
  /// [mood]（その日の調子バイアス）の分だけ全体を上下にずらす。
  int _drawValue(int mood) {
    final r = _random.nextDouble();
    final base = r < 0.45
        ? 0
        : r < 0.65
            ? 1
            : r < 0.85
                ? -1
                : r < 0.92
                    ? 2
                    : -2;
    return (base + mood).clamp(-2, 2);
  }
}
