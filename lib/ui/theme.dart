import 'package:flutter/material.dart';

/// 体調5段階（UI表示は1〜5）の色定義。DB上は-2〜2で保存される。
/// 変換は `conditionUiValue` / `conditionDbValue` を介して行い、
/// domain/ と data/ 層は常に -2〜2 の範囲で値を扱う。
enum ConditionLevel {
  worst(1, '最悪', Color(0xFFEF4444)),
  bad(2, '悪い', Color(0xFFF97316)),
  normal(3, '普通', Color(0xFF3B82F6)),
  good(4, '良い', Color(0xFF22C55E)),
  best(5, '最高', Color(0xFFA3E635));

  const ConditionLevel(this.uiValue, this.label, this.color);

  final int uiValue;
  final String label;
  final Color color;

  /// UI値(1〜5)からConditionLevelを取得する。
  static ConditionLevel fromUiValue(int uiValue) {
    return ConditionLevel.values.firstWhere((e) => e.uiValue == uiValue);
  }

  /// DB値(-2〜2)からConditionLevelを取得する。
  static ConditionLevel fromDbValue(int dbValue) {
    return fromUiValue(dbValue + 3);
  }
}

int conditionUiToDb(int uiValue) => uiValue - 3;

int conditionDbToUi(int dbValue) => dbValue + 3;

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF111827),
    scaffoldBackgroundColor: const Color(0xFFF7F8FB),
    fontFamily: 'sans-serif',
  );
}
