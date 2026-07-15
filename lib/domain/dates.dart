/// 日付境界の共通ヘルパー。
///
/// spec.md §4.2「レコードはtimestamp（端末ローカル時刻）が属する日にそのまま
/// 帰属させる」の「日の開始」定義をアプリ全体で一元化する。日境界の仕様を
/// 変更する場合（例: 深夜帯オフセットの導入）はここだけを直せばよい。
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// [date]が属する月の初日（時刻は00:00）。
DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);
