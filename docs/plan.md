# self-track-v3 v1.0 実装計画

design.md（特に §1.1 v1.0 スコープ）を実装に落とすための計画書。
v1.0 のゴールは **「main にマージできる、動作するシンプルなバージョン」** であり、Track / Tags / Calendar / Stats（フェーズ1）/ 最小 Settings を含む。

---

## 1. 技術スタックの確定

| 項目 | 採用 | 理由・補足 |
| :--- | :--- | :--- |
| フレームワーク | Flutter (stable) | Android 主眼、iOS 互換（design.md 既定） |
| ローカルDB | Drift (SQLite) | リアクティブな `watch()` ストリームで UI 更新（design.md 既定） |
| 状態管理 | Riverpod (`flutter_riverpod`) | Drift のストリームを `StreamProvider` に流すだけで画面が追従する。規模的に BLoC は過剰 |
| グラフ | `fl_chart` | 体調推移のスプライン描画、カレンダー下部のドーナツ/スパークライン（design.md 既定） |
| ID生成 | `uuid` | UUID v4 を TEXT 主キーとして保存 |
| 日付処理 | `intl` | 表示フォーマットのみ。タイムゾーンは端末ローカルに従い変換しない |
| ナビゲーション | 標準 `Navigator` + `Drawer` | モックのハンバーガーメニュー（☰）から5画面を切替。ルーティングライブラリは導入しない |
| Lint | `flutter_lints`（デフォルト） | 追加ルールは入れない |

統計計算（Fisher の正確確率検定など）は依存を増やさず自前実装する（§6.3 参照）。

## 2. ディレクトリ構成

```
lib/
├── main.dart
├── data/                    # 永続化層
│   ├── database.dart        # Drift データベース定義（テーブル・接続）
│   ├── tables.dart          # Records / Tags / RecordTags テーブル
│   └── daos/
│       ├── records_dao.dart # レコードCRUD + タグ紐付け + 期間クエリ
│       └── tags_dao.dart    # タグCRUD + アーカイブ
├── domain/                  # 純粋ロジック層（Flutter非依存・全て単体テスト対象）
│   ├── models.dart          # RecordWithTags などのUI向けモデル
│   ├── condition_series.dart# 12時間減衰の仮想ポイント挿入（design.md §4.1）
│   ├── daily_score.dart     # 台形公式によるAUC・日次スコア（design.md §4.2）
│   └── stats/
│       ├── time_window.dart # 時間窓集計の共通基盤（design.md §4.3）
│       ├── event_locked.dart# イベントロック平均
│       ├── contingency.dart # 2×2分割表・オッズ比・リフト値
│       └── fisher.dart      # Fisherの正確確率検定（自前実装）
├── providers/               # Riverpodプロバイダ（DB・DAO・画面状態）
└── ui/
    ├── app.dart             # MaterialApp / Drawer / 画面切替
    ├── theme.dart           # 体調5段階カラー等の定数
    ├── track/               # Track画面（タイムライン + Composer）
    ├── calendar/            # Calendar画面
    ├── stats/               # Stats画面
    ├── tags/                # Tags画面
    └── settings/            # Settings画面
```

方針: **domain/ は Flutter に依存させない**。減衰・AUC・統計はすべて純 Dart 関数とし、単体テストで固める。UI は Drift ストリーム + domain 関数の合成に徹する。

## 3. 共通仕様の確定事項

### 3.1 体調値のマッピング
- DB は design.md 通り `-2〜2`（DEFAULT 0）で保存する。
- UI は `1〜5` で表示する（`ui = db + 3`）。変換は UI 層（theme.dart 付近の定数・関数）でのみ行い、domain/ と data/ は常に `-2〜2` で扱う。

### 3.2 体調5段階カラー（モック準拠）
| UI値 | ラベル | 色 |
| :-- | :-- | :-- |
| 1 | 最悪 | `#EF4444` |
| 2 | 悪い | `#F97316` |
| 3 | 普通 | `#94A3B8` |
| 4 | 良い | `#22C55E` |
| 5 | 最高 | `#3B82F6` |

### 3.3 日時の扱い
- `timestamp` は端末ローカル時刻で保存・解釈する（Drift の DATETIME はエポック秒格納だが、日付への帰属計算はローカル変換後に行う）。
- 日付への帰属は timestamp の属する日そのまま。深夜特例なし（design.md §4.2）。

## 4. マイルストーン

依存関係順に M0→M7 で進める。各マイルストーンは単独でコミット可能な粒度とし、完了条件（DoD）を満たしてから次へ進む。

### M0: プロジェクト雛形
- `flutter create`（org 等は作成時に決定）、不要なサンプルコード削除。
- 依存パッケージ導入（drift, drift_flutter, flutter_riverpod, fl_chart, uuid, intl / dev: build_runner, drift_dev, flutter_lints）。
- Drawer で5画面（全て仮のプレースホルダ）を切り替えられる骨格。
- **DoD**: Android 実機/エミュレータで起動し5画面を行き来できる。`flutter analyze` がクリーン。

### M1: データ層（Drift）
- design.md §3 の3テーブルを定義。スキーマは以下の通り。

```dart
class Records extends Table {
  TextColumn get id => text()();                       // UUID v4
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get comment => text().nullable()();
  IntColumn get value => integer().withDefault(const Constant(0))(); // -2..2
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  @override Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get group => text().named('tag_group')(); // groupはSQL予約語のため列名を変更
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}

class RecordTags extends Table {
  TextColumn get recordId => text().references(Records, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id)();
  RealColumn get value => real().withDefault(const Constant(1.0))(); // v1.0では常に1.0
  @override Set<Column> get primaryKey => {recordId, tagId};
}
```

- インデックス: `records.timestamp`（期間クエリが全画面の基盤になるため）。
- DAO:
  - RecordsDao: 作成（タグ紐付け込みのトランザクション）、更新、削除、`watchByDateRange(from, to)`、全件ストリーム。
  - TagsDao: 作成、更新、アーカイブ/解除、`watchActive()`（選択候補用）、`watchAll()`（Tags画面用）。
- `updatedAt` / `isDirty` は書き込み時に DAO 内で自動設定する（v1.0 で同期はしないが値は正しく維持する）。
- **DoD**: DAO の単体テスト（インメモリSQLite: `NativeDatabase.memory()`）が通る。カスケード削除・UNIQUE制約・アーカイブフィルタを検証。

### M2: Tags 画面
Track がタグ選択に依存するため、UI は Tags から作る。
- 有効タグ一覧 + アーカイブ済み一覧（折りたたみ）のリスト表示。グループごとにセクション分け。
- 新規追加ダイアログ（name 必須・group 必須）。group は既存グループ候補のサジェスト + 自由入力。
- 編集（name / group 変更）、アーカイブ、アーカイブ解除。物理削除は提供しない。
- **DoD**: タグの追加→編集→アーカイブ→解除が一通り動き、アーカイブ済みタグが選択候補ストリームに出ないこと。

### M3: Track 画面（mock/track.html 準拠）
v1.0 の中核。モックの5状態を実装する。
- **タイムライン**: 当日のレコードを新しい順に表示（時刻 / 体調バッジ / タグチップ / コメント）。ヘッダの日付タップで過去日の表示に切替（記録は常に「今」の時刻で作成）。
- **Composer（通常状態）**: 画面下部固定。`+` でパネル展開、テキスト欄タップでコメント入力。
- **上伸びパネル**: Status 5段階ピル（デフォルト「普通」= 0 選択済）。「タグを追加」でタグゾーンがアコーディオン展開（最近使ったタグ + グループ別）。⛶ で全画面タグ選択オーバーレイ。
- **選択後**: 選択タグは Composer 内チップ（× で解除）として表示。送信（↑）で record + record_tags をトランザクション作成しパネルを閉じる。
- **タグ未登録時**: 有効タグが0件なら「タグを追加」ボタンを非表示（design.md §5.1）。
- **編集・削除**: タイムライン項目の**長押し**でボトムシート（編集 / 削除）。編集は Composer をそのレコードの内容で開く。削除は確認ダイアログを挟む。
- 「最近使ったタグ」= record_tags を timestamp 降順で辿った直近ユニーク数件（上限8）。
- **DoD**: 記録の作成・編集・削除がタイムラインに即時反映される。タグ0件時の表示分岐を確認。

### M4: 計算ロジック（domain/）
UI から独立して先にテストで固める。
- `condition_series.dart`: レコード列 + 現在時刻 → 仮想ポイント込みの時系列（design.md §4.1）。
  - 隣接ログ間が12時間超なら `T_A + 12h` に value=0 を挿入。
  - 最終ログから12時間超経過なら `T_L + 12h` に 0 を挿入し、now も 0 とする。
- `daily_score.dart`: 指定日の 00:00〜24:00 を台形公式で積分（design.md §4.2）。
  - 00:00 / 24:00 の値は前後レコード（仮想ポイント含む）からの線形補間。
  - 日にレコードが1件もなく前後からの補間もできない場合はスコア `null`（= カレンダー上は空白日）。
  - 日次スコアは 24h で正規化した平均値（-2〜2）としても取得できるようにする（カレンダーの色分け・平均表示に使用）。
- **DoD**: 単体テストで以下を網羅 — 12時間ちょうど/超え、日跨ぎ補間、レコード0件日、単一レコード日、now が減衰中のケース。

### M5: Calendar 画面（mock/calendar.html 案1準拠）
- **月グリッド**: 案1「そのまま」を採用。各日は日次平均スコア（M4）を5段階に丸めた単色ドット + 日付数字。記録なし日は空白。
- **月ナビゲーション**: `‹ 2026年6月 ›` 形式で前後月へ移動。
- **今月の割合**: 5段階それぞれの日数・割合のドーナツチャート + 月平均値 + 前月比バッジ。
- **7日間の傾向**: 直近7日の日次スコアのスパークライン（基準線=普通、fl_chart のスプライン描画）+ 7日平均と前週比。
- 日セルのタップで該当日の Track タイムライン表示へ遷移。
- **DoD**: 月切替・当月統計・7日傾向がダミーでなく実データから描画される。

### M6: Stats 画面（フェーズ1）
共通基盤 → 3指標の順に実装する。
- `time_window.dart`（共通基盤）: タグ発生時刻を起点とした時間窓（0–3h / 3–6h / 6–12h）での condition サンプリングと、タグ×日の発生行列の生成。
- **イベントロック平均**: 対象タグの各発生時刻を 0 とし、-12h〜+12h を1時間刻みで condition 曲線（仮想ポイント込み）からサンプリングして全発生分を平均。折れ線グラフで表示し、ベースライン0との差を見る。
- **オッズ比 + Fisher 正確確率検定**: v1.0 は**日単位の共起**で 2×2 分割表を作る（「actionタグのあった日」×「symptomタグのあった日」）。時間窓ベースの精密化はフェーズ2以降。Fisher は対数階乗（`logGamma` 相当のテーブル/逐次和）による超幾何分布の両側検定を自前実装。
- **リフト値**: `P(症状日|行動日) / P(症状日)`。UI の主表示はリフト値とし、オッズ比・p値は詳細として添える。
- **UI構成**:
  1. 直近30日の体調スコア推移グラフ。
  2. タグを1つ選ぶ → イベントロック平均グラフ。
  3. 行動タグ×症状タグの関連リスト（リフト値降順、p値・発生回数併記。発生回数が閾値未満の組は「データ不足」表示）。
- **DoD**: fisher.dart / contingency.dart / event_locked.dart の単体テスト（既知の教科書値と照合）が通り、実データで3表示が動く。

### M7: Settings + 仕上げ
- Settings: 「データの全削除」のみ（確認ダイアログ2段階）。
- 全画面の空状態（データ0件）表示の整備。
- ダークモード対応はモックにCSSがあるが **v1.0 ではライトのみ**とし、Theme 定数は分離しておく。
- 手動QAチェックリスト（§7）の消化、README 簡易更新。
- **DoD**: §7 の受け入れ基準をすべて満たし、main へマージ。

## 5. 画面とデータの接続方針

- DB接続・DAO は Riverpod の `Provider` でシングルトン供給。
- 一覧系（タイムライン、タグ一覧、月のレコード）は DAO の `watch*()` を `StreamProvider.family`（日付・月をキー）で公開し、画面は `ref.watch` するだけにする。
- Composer の編集中状態（選択タグ・体調値・コメント・編集対象ID）は `NotifierProvider` で1つの state クラスに集約。
- 統計は同期計算で開始し、実測で 100ms を超える場合のみ `compute()`（isolate）へ逃がす。早期の最適化はしない。

## 6. アルゴリズム実装の注意点

### 6.1 減衰・AUC
- 仮想ポイント挿入は「描画・計算時にメモリ上で行い、DBには保存しない」（design.md §4.1）。`condition_series.dart` の純関数として、入力（レコード列, now）→ 出力（時系列点列）を固定する。
- fl_chart のスプラインは表示専用。スコア計算は必ず台形公式の線形補間で行う（オーバーシュート防止、design.md §4.2）。

### 6.2 日次スコアの5段階丸め（カレンダー用）
- 日次平均（-2.0〜2.0 連続値）→ 最近傍の整数に丸めて色を決定（-0.5〜0.5 → 普通、など）。丸め規則は `daily_score.dart` に関数として置き、テストする。

### 6.3 Fisher 正確確率検定
- 2×2 の周辺和固定の超幾何分布で、観測表以下の確率を持つ全ての表の確率和（両側）。
- 対数空間で計算（`logFactorial` を逐次和で実装）してアンダーフローを回避。想定 n は高々数百なので前計算テーブルで十分。
- 検証: R の `fisher.test` の既知例（例: 3,1,1,3 → p=0.4857）をテストに固定。

### 6.4 オッズ比のゼロ対策
- 分割表に 0 セルがある場合は Haldane 補正（各セル +0.5）でオッズ比を算出し、UI に補正済みであることは出さない（p値は補正なしの Fisher を使う）。

## 7. テスト・受け入れ基準

### 自動テスト
- **domain/ 全関数の単体テスト**（M4, M6）— 本計画で最も投資する箇所。
- **DAO テスト**（M1）— インメモリDBで CRUD・制約・ストリームを検証。
- ウィジェットテストは Composer の状態遷移（タグ0件で追加ボタン非表示、送信で state リセット）のみ最小限。
- CI 相当として、コミット前に `flutter analyze && flutter test` を通す。

### 手動QAチェックリスト（v1.0 受け入れ基準）
1. 体調のみ / 体調+タグ / 体調+タグ+コメント の3パターンで記録が作成できる。
2. 記録の長押し→編集で内容が変わり、長押し→削除で消える（record_tags も残留しない）。
3. タグ0件の初回起動時、Composer にタグ追加ボタンが出ない。Tags 画面でタグを作ると出る。
4. 使用中タグをアーカイブしても過去のタイムライン表示・統計が壊れない。
5. カレンダー: 記録のない日が空白、複数記録日が平均色になる。月移動が正しい。
6. 12時間以上記録を空けたとき、推移グラフが0に減衰して見える。
7. Stats: タグ選択でイベントロック平均が描画され、行動×症状リストにリフト値と p 値が出る。データ不足の組が「データ不足」と表示される。
8. Settings の全削除後、全画面が空状態表示になりクラッシュしない。

## 8. スコープ外（再確認）

- クラウド同期・バックアップ（`updatedAt` / `isDirty` の維持のみ行う）
- `record_tags.value` の入力UI（常に1.0）
- 統計フェーズ2以降（正則化回帰、ラグ探索、ベイズ）
- エクスポート/インポート
- ダークモード
- 通知・リマインダー

## 9. リスクと対応

| リスク | 対応 |
| :--- | :--- |
| Fisher/オッズ比が少データで意味を持たない | 発生回数の閾値（例: 双方3回以上）未満は「データ不足」と明示して数値を出さない |
| `group` が SQLite 予約語 | 列名を `tag_group` にリネームして回避（Dart側プロパティは `group` のまま） |
| fl_chart スプラインのオーバーシュートで「6」等に見える | 表示レンジを ±2 にクランプ。計算は線形なので影響なし |
| 統計計算がメインスレッドを塞ぐ | まず同期実装 → 実測で遅ければ `compute()` へ（§5） |
