# 実装タスク一覧

> **暫定版**：作業単位ドキュメントの様式（記載ルール）が未整備の状態で作成した（`docs/backlog.md` 023）。

## タスク

- [x] 1. Python仮想環境とdbtを導入する
    - [x] リポジトリ直下に`.venv/`を作成する（`python -m venv .venv`）
    - [x] 実装時点の最新の安定版の`dbt-core`・`dbt-snowflake`を導入し、Python 3.13で動作することを確認する
    - [x] `requirements.txt`を作成し、`dbt-core`・`dbt-snowflake`を`==`で固定する
- [x] 2. 接続用の環境変数を設定する
    - [x] `SNOWFLAKE_ACCOUNT`・`SNOWFLAKE_USER`・`SNOWFLAKE_PRIVATE_KEY_PATH`を設定する（値は既存の`connections.toml`と同じ。秘密鍵の中身は読まない）
- [x] 3. dbtプロジェクトを初期設定する
    - [x] `dbt/dbt_project.yml`を作成する（stagingは`STAGING`スキーマ・`view`、martsは`MARTS`スキーマ・`table`）
    - [x] `dbt/profiles.yml`を作成する（`dev`（既定）／`prod`の2つの`target`。値は`env_var()`で参照）
    - [x] `dbt/macros/generate_schema_name.sql`で、カスタムスキーマ名をそのまま使うよう上書きする
    - [x] `dbt debug`で`target: dev`の接続を確認する
- [x] 4. ダミーデータに2月の支出の行を追加する
    - [x] `sample_data/`のダミーCSVに`DUMMY-0000000008`（1900/02/01、`sample_shop_feb`、-4000、食費）を追加する（Shift-JISのまま）
    - [x] 既存の取り込みスクリプトで`RAW_DEV`に取り込み、8行になったことを確認する
- [x] 5. sourceを定義する
    - [x] `dbt/models/staging/moneyforward/_moneyforward__sources.yml`を作成する（参照先DBは`RAW_{{ target.name | upper }}`）
    - [x] 全列の`description`に元のCSVの列名と、要件定義書「前提となるデータ仕様」の内容を記載する
    - [x] `id`に`not_null`・`unique`、`is_target`・`category_major`・`amount`・`transaction_date`に`not_null`のテストを設定する
- [x] 6. stagingモデルを作成する
    - [x] `stg_moneyforward__transactions.sql`を作成する（`id`→`transaction_id`のリネームのみ）
    - [x] `_moneyforward__models.yml`に列定義と、`transaction_id`の`not_null`・`unique`のテストを記載する
- [x] 7. martsモデルを作成する
    - [x] `mart_transactions.sql`を作成する（区分の判定・金額の算出）
    - [x] `_marts__models.yml`に列定義と、`transaction_id`の`not_null`・`unique`、`transaction_type`の`not_null`・`accepted_values`のテストを記載する
    - [x] 同ファイルに、区分の判定・金額の算出のunit test（テストケース一覧No.16・17の入力(a)〜(e)）を記載する
    - [x] `tests/assert_mart_transactions_has_all_rows.sql`（stagingとmartsの件数の一致）を作成する
- [x] 8. `dbt run`・`dbt test`を実行し、エラーがあれば修正する
- [x] 9. テストケース一覧に従ってテストを実施し、結果と対応テスト名を記録する
- [x] 10. リリース手順書`release.md`を作成し、ユーザーのレビューを受ける
- [x] 11. 永続ドキュメントを更新する
    - [x] `docs/development-standards.md`に「6. Python実行環境」を追加する（概要の対象一覧も更新する）
    - [x] `docs/repository-structure.md`に`requirements.txt`・`.venv/`・`dbt/`の実際の構成・`release.md`を反映する
    - [x] `docs/interfaces.md`の「列定義の詳細」の参照先を`sources.yml`の実際のパスに更新する
    - [x] `docs/architecture.md`にdbtの環境切り替え方法を追記する
    - [x] `docs/architecture.md`の「アカウントセキュリティ」に、Snowflakeへの接続に関わる情報の区分を追記する（テストケースNo.7の協議を受けて追加）
- [ ] 12. PRを作成し、CIレビューを通す
- [ ] 13. ユーザーの確認を受け、`main`にsquashマージし、featureブランチを削除する
- [ ] 14. （ユーザー実施）`release.md`に沿ってPRODへリリースする
