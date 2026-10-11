# IF一覧

## 概要
本書は、本データ基盤へ取り込まれているIF（接続先から連携される個々のデータ）とその詳細情報を一覧化する。実装の進捗に応じて、都度更新する管理用ドキュメントとする。

- 各IFがどの接続先から来ているかは「対応する接続先」列で`docs/connections.md`（接続先一覧）に紐づける。
- 列定義（スキーマ）の詳細はここには記載せず、dbtの`sources.yml`に委譲する（`CLAUDE.md`の詳細設計をdbtアセットに委譲する方針と同様）。

## 一覧

| IF名 | 対応する接続先 | 取得方法 | 取得頻度 | ファイル形式 | 格納先 | 稼働状況 | 備考 |
|---|---|---|---|---|---|---|---|
| 収入・支出詳細CSV | マネーフォワード | 手動CSVエクスポート | 週次 | CSV（Shift-JISエンコーディング） | `s3://practice-data-platform-raw/<prod\|dev>/moneyforward/transactions/inbox/`（取り込み成功後`archive/`へ移動。詳細は`.steering/20261003-ingestion-pipeline/design.md`） | 稼働中（取り込みパイプライン構築・動作確認済み。マネーフォワード側からの実データでの本番運用は未開始） | 列定義の詳細はdbtの`dbt/models/staging/moneyforward/_moneyforward__sources.yml`を参照 |
