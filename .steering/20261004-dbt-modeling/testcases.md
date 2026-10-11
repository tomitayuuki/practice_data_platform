# テストケース一覧（作業単位）

> **暫定版**：作業単位ドキュメントの様式（記載ルール）が未整備の状態で作成した（`docs/backlog.md` 023）。表の列は`docs/development-standards.md`5章の様式に従う。

テストは原則として`sample_data/`のダミーCSVを取り込んだ`RAW_DEV`に対し、`target: dev`で実施する。PRODでの実施（リリース）は本一覧の対象外とし、`release.md`に沿ってユーザーが行う。

## 期待値の根拠（ダミーデータ）
No.10・14・18〜20の期待値は、基本設計書「ダミーデータの追加」を反映した後の`sample_data/`のダミーCSV（8行）に基づく。

| 内容 | 日付 | 計算対象 | 大項目 | 金額（円） |
|---|---|---|---|---|
| sample_shop | 1900/01/01 | 1 | XX費 | -9999 |
| sample_salary | 1900/01/02 | 1 | 収入 | 300000 |
| sample_grocery | 1900/01/03 | 1 | 食費 | -3000 |
| sample_transfer | 1900/01/04 | 0 | 振替 | -10000 |
| sample_utility | 1900/01/05 | 1 | 水道光熱費 | -5000 |
| sample_refund | 1900/01/06 | 1 | XX費 | 1500 |
| sample_unknown | 1900/01/07 | 1 | 未分類 | -2000 |
| sample_shop_feb | 1900/02/01 | 1 | 食費 | -4000 |

## dbt実行環境

| No. | 対象要件 | 確認内容 | 期待結果 | 対応テスト名（任意） | 実施結果 | 実施日 |
|---|---|---|---|---|---|---|
| 1 | 要件定義書「dbt実行環境」：dbtが`.venv/`にのみ導入されていること | 仮想環境を有効化しない状態で、PC全体のPythonにdbtが導入されていないかを確認する（`python -m pip show dbt-core`） | 仮想環境外ではdbtが見つからない。仮想環境内では`dbt --version`が成功する |  | PASS | 2026-10-09 |
| 2 | 要件定義書「dbt実行環境」：`requirements.txt`から同じバージョンを再現して導入できること／基本設計書「Python仮想環境」 | `requirements.txt`の記載を確認する。その後、一時的に別名の仮想環境を新規作成し、`requirements.txt`から導入して`dbt --version`を確認した後、その仮想環境を削除する | `requirements.txt`に`dbt-core`・`dbt-snowflake`が`==`で固定されている。新しい仮想環境の`dbt --version`が示すdbt-core・dbt-snowflakeのバージョンが、`requirements.txt`の記載および元の`.venv`と一致する |  | PASS | 2026-10-09 |
| 3 | 要件定義書「dbt実行環境」：`target: dev`で`RAW_DEV`のみを参照し`ANALYTICS_DEV`のみに書き込むこと／基本設計書「接続設定」（既定の`target`は`dev`）・「環境の切り替え」 | `--target`を指定せずに`dbt run`を実行し、使われた`target`・コンパイル済みSQL（`target/`配下）の参照先・作成されたオブジェクトの場所を確認する | 実行ログ上の`target`が`dev`。sourceの参照先が`RAW_DEV.MONEYFORWARD.TRANSACTIONS`。モデルは`ANALYTICS_DEV`内にのみ作成され、`ANALYTICS_PROD`には何も作成・変更されない |  | PASS | 2026-10-09 |
| 4 | 要件定義書「dbt実行環境」：`target: prod`の場合は`RAW_PROD`／`ANALYTICS_PROD`の組み合わせとなること | `dbt ls --target prod --output json`で、sourceとモデルの`database`・`schema`を確認する（`dbt ls`はプロジェクトの解析のみでSnowflakeに接続しないため、PRODへのアクセスは発生しない） | sourceが`RAW_PROD`.`MONEYFORWARD`、stagingモデルが`ANALYTICS_PROD`.`STAGING`、martsモデルが`ANALYTICS_PROD`.`MARTS`となる |  | PASS | 2026-10-09 |
| 5 | 要件定義書「dbt実行環境」：環境を跨いだ参照をしないこと／基本設計書「環境の切り替え」（設定を誤っても権限エラーで止まる） | `SHOW GRANTS TO ROLE TRANSFORMER_DEV`で、`TRANSFORMER_DEV`の権限と、付与されている他のロールを確認する | `RAW_PROD`・`ANALYTICS_PROD`に関する権限が1件も無い。他のロールが付与されていない（付与されている場合は、そのロールにも`RAW_PROD`・`ANALYTICS_PROD`の権限が無い） |  | PASS | 2026-10-09 |
| 6 | 基本設計書「dbtプロジェクトの構成」（マテリアライゼーション）・「スキーマ名（`generate_schema_name`マクロ）」 | `dbt run`後、各モデルが作成されたスキーマ名とオブジェクトの種類を確認する | `ANALYTICS_DEV.STAGING.STG_MONEYFORWARD__TRANSACTIONS`（view）、`ANALYTICS_DEV.MARTS.MART_TRANSACTIONS`（table）として作成される。`STAGING_MARTS`のような連結名のスキーマは作られない |  | PASS | 2026-10-09 |
| 7 | 要件定義書「dbt実行環境」：認証情報がリポジトリ・Gitの管理対象に含まれないこと／基本設計書「接続設定」 | `profiles.yml`の内容と、Git管理対象のファイル全体に、秘密鍵の中身・アカウント識別子が含まれていないかを確認する。また、`dbt run`後に`git status`を実行し、dbtの生成物が管理対象外であることを確認する | `profiles.yml`のアカウント識別子・ユーザー名・秘密鍵のパスは`env_var()`による参照のみ。Git管理対象に秘密鍵の中身・アカウント識別子は含まれない。`dbt/target/`・`dbt/logs/`・`.user.yml`は`git status`に表示されない |  | PASS（補足参照） | 2026-10-09 |

## source・staging

| No. | 対象要件 | 確認内容 | 期待結果 | 対応テスト名（任意） | 実施結果 | 実施日 |
|---|---|---|---|---|---|---|
| 8 | 要件定義書「テスト」：主キーに`not_null`・`unique`（source）／基本設計書「テスト方針」（判定・金額・軸に使う列の`not_null`） | sourceの`id`列の欠損・重複、`is_target`・`category_major`・`amount`・`transaction_date`列の欠損をテストする | いずれも0件 | `source_not_null_moneyforward_transactions_id`／`source_unique_moneyforward_transactions_id`／`source_not_null_moneyforward_transactions_is_target`／`source_not_null_moneyforward_transactions_category_major`／`source_not_null_moneyforward_transactions_amount`／`source_not_null_moneyforward_transactions_transaction_date` | PASS | 2026-10-09 |
| 9 | 要件定義書「テスト」：主キーに`not_null`・`unique`（staging） | stagingの`transaction_id`列の欠損・重複をテストする | 欠損・重複が0件 | `not_null_stg_moneyforward__transactions_transaction_id`／`unique_stg_moneyforward__transactions_transaction_id` | PASS | 2026-10-09 |
| 10 | 要件定義書「staging」：`RAW`の取引テーブルと1対1で対応すること | sourceとstagingの件数を比較する | 件数が一致する（ダミーデータでは8件） |  | PASS | 2026-10-09 |
| 11 | 要件定義書「staging」：最低限のクレンジングのみを行う（ビジネスロジックを含めない）／基本設計書「staging」の列定義 | stagingの列名・型・値を、基本設計書の列定義およびsourceの値と比較する | `id`→`transaction_id`のリネーム以外、列・値はsourceと同じ。区分の判定・金額の変換等の列は無い |  | PASS | 2026-10-09 |
| 12 | 要件定義書「前提となるデータ仕様」（列単位の仕様を`sources.yml`に記載する）／基本設計書「source」 | `_moneyforward__sources.yml`の各列の`description`を確認する | 全列に元のCSVの列名が記載されている。`amount`に金額の符号（収入・返金は正、支出は負）と、返金が元の支出と同じ大項目に分類されること、`is_target`に計算対象の意味（振替・NISA積立・手動での計算対象外）が記載されている |  | PASS | 2026-10-09 |

## marts

| No. | 対象要件 | 確認内容 | 期待結果 | 対応テスト名（任意） | 実施結果 | 実施日 |
|---|---|---|---|---|---|---|
| 13 | 要件定義書「テスト」：主キーに`not_null`・`unique`（marts） | martsの`transaction_id`列の欠損・重複をテストする | 欠損・重複が0件 | `not_null_mart_transactions_transaction_id`／`unique_mart_transactions_transaction_id` | PASS | 2026-10-09 |
| 14 | 要件定義書「marts」：`RAW`の全行（収入・支出・計算対象外のすべて）を含むこと | stagingとmartsの件数を比較する | 件数が一致する | `assert_mart_transactions_has_all_rows` | PASS | 2026-10-09 |
| 15 | 要件定義書「marts」：区分の列を持つこと／基本設計書「区分の判定」（値は`income`／`expense`／`excluded`） | `transaction_type`の欠損と、許可された値以外の混入をテストする | 欠損0件。値は`income`／`expense`／`excluded`のいずれかのみ | `not_null_mart_transactions_transaction_type`／`accepted_values_mart_transactions_transaction_type__income__expense__excluded` | PASS | 2026-10-09 |
| 16 | 要件定義書「marts」：区分の判定ルール／基本設計書「区分の判定」 | 以下の入力行に対し、期待する区分に変換されることをunit testで検証する：(a) 計算対象=1・大項目=収入（給与）→`income`、(b) 計算対象=1・大項目=食費・負の金額（買い物）→`expense`、(c) 計算対象=1・大項目=食費・正の金額（返金）→`expense`、(d) 計算対象=0・大項目=振替（振替）→`excluded`、(e) 計算対象=0・大項目=収入・正の金額（計算対象外にした収入）→`excluded` | (a)〜(e)がすべて期待どおりの区分になる。特に(e)で計算対象外の判定が大項目より優先される | `mart_transactions::test_mart_transactions_classification_and_amount`（unit test） | PASS | 2026-10-09 |
| 17 | 要件定義書「marts」：金額を2通りで持つこと／基本設計書「金額の算出」 | No.16と同じ入力行に対し、`amount`・`signed_amount`が期待どおりに算出されることをunit testで検証する | (a) 300000 → `amount`=300000、(b) -3000 → 3000、(c) 1500 → -1500、(d) -10000 → NULL、(e) 50000 → NULL。`signed_amount`はすべて入力の金額のまま | `mart_transactions::test_mart_transactions_classification_and_amount`（unit test。No.16と同一） | PASS | 2026-10-09 |
| 18 | 要件定義書「受け入れ基準」：ダミーデータの各行が想定どおりの区分・金額になっていること／基本設計書「marts」の列定義 | `dbt run`後、`ANALYTICS_DEV.MARTS.MART_TRANSACTIONS`の列名・型と、全8行の`transaction_type`・`amount`・`signed_amount`を確認する | 列名・型が基本設計書の列定義（12列）と一致する。sample_shop：expense／9999、sample_salary：income／300000、sample_grocery：expense／3000、sample_transfer：excluded／NULL、sample_utility：expense／5000、sample_refund：expense／-1500、sample_unknown：expense／2000、sample_shop_feb：expense／4000。`signed_amount`は「期待値の根拠」の金額のまま |  | PASS | 2026-10-09 |
| 19 | 要件定義書「marts」：Snowsightで支出に絞り込み、月×大項目で合計するだけでカテゴリ別の月次支出推移が得られること／基本設計書「閲覧用ロールの権限」 | `REPORTER_DEV`ロールで、`transaction_type = 'expense'`に絞り込み、`transaction_date`の月×`category_major`で`amount`を合計するクエリを実行する | 権限エラーなく実行できる。1900年1月：XX費 8499（9999−1500）、食費 3000、水道光熱費 5000、未分類 2000。1900年2月：食費 4000。食費が月ごとに分かれて集計される |  | PASS | 2026-10-09 |
| 20 | 要件定義書「marts」・基本設計書「金額の算出」：収支は`excluded`以外の`signed_amount`の合計で求められること | `transaction_type <> 'excluded'`の行の`signed_amount`を合計する | 300000 − 9999 − 3000 − 5000 + 1500 − 2000 − 4000 = 277501 |  | PASS | 2026-10-09 |

## 実行・リリース・ドキュメント

| No. | 対象要件 | 確認内容 | 期待結果 | 対応テスト名（任意） | 実施結果 | 実施日 |
|---|---|---|---|---|---|---|
| 21 | 要件定義書「受け入れ基準」：`dbt run`・`dbt test`（`target: dev`）が成功すること／基本設計書「テスト方針」（重要度`error`、外部パッケージを導入しない） | `RAW_DEV`にダミーCSVが取り込まれた状態で、`dbt run`・`dbt test`を実行する。あわせて、テストの`severity`を`warn`にしている箇所が無いこと、`packages.yml`が無いことを確認する | すべてのモデルの作成と、すべてのテスト（unit testを含む）が成功する。`severity: warn`の指定が無く、`packages.yml`が存在しない |  | PASS | 2026-10-09 |
| 22 | 要件定義書「リリース」：初回リリースに必要な作業を上から順に実施すれば完了する手順書があること／基本設計書「リリース手順（概要）」 | `release.md`の内容を確認する | 基本設計書の1〜6（前提の確認、実データの`RAW_PROD`への取り込み、`dbt run --target prod`、`dbt test --target prod`、結果の確認、失敗時の対応）がすべて、具体的なコマンド・操作として順番に記載されている |  | PASS | 2026-10-09 |
| 23 | 要件定義書「受け入れ基準」：リリース手順書がユーザーのレビューで承認されていること | ユーザーに`release.md`のレビューを依頼する | ユーザーの承認が得られる |  |  |  |
| 24 | 要件定義書「永続ドキュメントの更新」／基本設計書「永続ドキュメントの更新」 | 各永続ドキュメントの更新内容を確認する | `development-standards.md`に「6. Python実行環境」、`repository-structure.md`に`requirements.txt`・`.venv/`・`dbt/`の実際の構成・`release.md`、`interfaces.md`に`sources.yml`の実際のパス、`architecture.md`にdbtの環境切り替え方法と、Snowflakeへの接続に関わる情報の区分、`backlog.md`に022・023が、それぞれ反映されている |  | PASS | 2026-10-09 |

## テストの対象外とした項目
- `target`名を`dev`／`prod`以外にした場合の挙動：運用上の制約であり、それ以外の名前で実行する想定が無いため
- 手順書に沿ってPRODリリースが実際に完了すること：PRODでの実施はユーザーが行うため、本一覧では手順書の内容の確認（No.22）と承認（No.23）までとする
- dbt Fusionを採用しないこと等、ツールの選定：選定の判断であり、導入されたパッケージ（No.2）で確認できる

## 実施結果の補足
- **No.1**：仮想環境外で`python -m pip show dbt-core`を実行し「Package(s) not found」となることを確認。仮想環境内の`dbt --version`はdbt-core 1.12.5／dbt-snowflake 1.12.1。
- **No.2**：`requirements.txt`は`dbt-core==1.12.5`・`dbt-snowflake==1.12.1`の2行。一時的な仮想環境に導入し同じバージョンになることを確認後、その仮想環境は削除した。
- **No.3**：`--target`指定なしの`dbt run`で、ログに`target='dev'`と表示。コンパイル済みSQLの参照先は`RAW_DEV.moneyforward.transactions`。`ANALYTICS_PROD`の`INFORMATION_SCHEMA`以外のオブジェクトは0件のまま。
- **No.4**：`dbt ls --target prod`の結果、sourceが`RAW_PROD`.`moneyforward`、stagingが`ANALYTICS_PROD`.`staging`、martsが`ANALYTICS_PROD`.`marts`。Snowflakeへの接続は発生しない。
- **No.5**：`TRANSFORMER_DEV`の権限は`RAW_DEV`・`ANALYTICS_DEV`・`MAIN_WH`に関するもののみ。付与されている他のロールは無い。
- **No.7**：今回追加・変更したファイルには、秘密鍵の中身・アカウント識別子・ユーザー名は含まれない（`profiles.yml`は`env_var()`による参照のみ）。`dbt/target/`・`dbt/logs/`は`git status`に表示されない。アカウント識別子・秘密鍵の中身はGit管理対象のどこにも含まれない。
    - 初回実施時は、期待結果に「ユーザー名」も含めていたところ、既存のGit管理対象ファイル`.steering/20260922-snowflake-infra-setup/setup.sql`（141〜146行目）にSnowflakeのユーザー名が記載されていたため、FAILとした。
    - ユーザーと協議し、ユーザー名はそれ自体では悪用できず、障害時の復旧でSQLから参照できるほうが都合がよいため、秘密としては扱わないこととした（漏らしてはならないのは秘密鍵の中身。アカウント識別子はコストをかけずに避けられるため公開しない）。基本設計書「接続設定」とNo.7の確認内容・期待結果を修正し、再確認の上PASSとした（2026-10-11）。
- **No.10・14**：source・staging・martsとも8件。
- **No.11**：sourceとstaging（`id`と`transaction_id`を対応させて比較）の差分は0行。列名・型は基本設計書の列定義どおり。
- **No.16・17**：unit testの有効性を確かめるため、一時的に区分の判定順（計算対象外と収入）を入れ替えて実行し、unit testが失敗することを確認した後、元に戻した。
- **No.18**：列名・型は基本設計書の12列どおり。各行の値は期待結果どおり。
- **No.19**：`REPORTER_DEV`ロールで実行し、権限エラーなし。1900年1月：XX費 8499、未分類 2000、水道光熱費 5000、食費 3000。1900年2月：食費 4000。
- **No.20**：277501。
- **No.21**：`dbt run`はPASS=2、`dbt test`はPASS=14（data test 13件・unit test 1件）。`severity`の指定は無く（既定の`error`）、`packages.yml`は存在しない。
- **事前準備**：`RAW_DEV`に、ダミーCSVの金額の符号を修正する前（PR #14より前）の行が残っていた（取り込みの`MERGE`は既存の`id`を更新しないため）。`RAW_DEV.MONEYFORWARD.TRANSACTIONS`の行を削除し、2月の行を追加したダミーCSVを取り込み直してから各テストを実施した。
