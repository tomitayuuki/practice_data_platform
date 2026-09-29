# 実装タスク一覧

## 進め方について
Snowflakeのアカウント設定（DB・スキーマ・ロール・ウェアハウス等の作成）はdbtが管理する対象ではなく、一度きりのセットアップ作業。そのためSQLスクリプトは`dbt/`ではなく、この作業単位のフォルダ内（`.steering/20260922-snowflake-infra-setup/setup.sql`）に置く。将来、ロールや権限をさらに変更する必要が出た場合は、その時点で新しい作業単位（`.steering/`）を作り、変更差分をそこに記録する。

SQLの実行は、Claude Codeから直接Snowflakeに接続する手段がないため、**Snowsightのワークシートにスクリプトを貼り付けてユーザーが実行する**形で進める。

## タスク

- [x] 1. `setup.sql`を作成する（`design.md`の構築手順1〜8に対応するDDLを、依存順に記述する）
    - [x] ウェアハウス`MAIN_WH`の作成
    - [x] リソースモニター`MONTHLY_BUDGET_MONITOR`の作成・`MAIN_WH`への紐付け（クレジット上限は暫定値を設定する旨をコメントで明記）
    - [x] データベース4つ（`RAW_PROD`／`RAW_DEV`／`ANALYTICS_PROD`／`ANALYTICS_DEV`）の作成
    - [x] 各データベース内のスキーマ作成
    - [x] ロール6つの作成
    - [x] 各ロールへの権限付与（DB／スキーマ／ウェアハウスの`USAGE`等）
    - [x] 個人ユーザーへの6ロール付与
- [ ] 2. MFA有効化の手順を案内する（Snowsight UI操作のため、SQLではなく手順書として提示する）
- [x] 3. `setup.sql`を実行する（当初はSnowsightでの手動実行を想定していたが、Snowflake CLIの接続構築が完了したため、Claude CodeがCLI経由で実行した）
- [ ] 4. デフォルトで存在するオブジェクト（`COMPUTE_WH`等）の扱いを確認し、対応する（削除、または用途を決めて残す）
- [ ] 5. 動作確認：`requirements.md`の受け入れ基準を満たしているか検証する
    - [ ] 全オブジェクトが設計通りに作成されていること
    - [ ] 各ロールが、自分の環境（DEV／PROD）を超えて参照・書き込みできないこと（例：`TRANSFORMER_DEV`で`ANALYTICS_PROD`に書き込めないことを確認）
- [ ] 6. `docs/backlog.md`・関連する永続ドキュメントの更新要否を確認する
