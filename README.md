# self-track-v3

体調管理と行動ログを記録し、行動と体調の因果関係を分析するためのFlutterアプリ。
製品仕様と実装計画は `docs/spec.md`、実行可能なフロントエンドモックは
`docs/frontend-spec.html` を参照。

## セットアップ

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Driftのコード生成
```

## 開発

```sh
flutter analyze
flutter test
flutter run
```

データは端末内のSQLite（Drift）にのみ保存され、クラウド同期は行わない（v1.0時点）。

## 画面構成

- **Today (Track)**: 体調・タグ・コメントの記録とタイムライン表示
- **Calendar**: 月単位の体調の推移と簡易統計
- **Analysis (Stats)**: 直近の体調推移、イベントロック平均、行動×症状の関連分析
- **Tags**: タグの追加・編集・アーカイブ
- **Settings**: データの全削除
