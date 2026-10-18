# テストケース一覧（作業単位）

## テストの実施時期
CDのワークフローは`main`でしか動かないため（基本設計書「マージ前に確認できる範囲」）、テストは以下の時期に分けて実施する。

| 時期 | 対象 | 実施者 |
|---|---|---|
| マージ前（開発フローのステップ4） | No.1〜9。ワークフローの定義・Environmentの設定の確認と、ローカルの`target: dev`での`dbt build`の確認 | Claude |
| マージ前（開発フローのステップ5の後） | No.10〜11。永続ドキュメントの確認 | Claude |
| マージ後（リリース中・リリース後） | No.12〜18。実際にCDを動かして確認する | Claude（GitHubの実行状況・ログの読み取り、PRODへの読み取りのみの`SELECT`・`SHOW`・`DESC`による確認）。承認・却下・手動実行のボタン操作は、リリース手順書に沿って依頼者が行う |

- マージ後のテストの結果は、リリース手順書の実施記録と同じ別のPR（以下「実施記録のPR」）で本一覧に記録する。ただしNo.18は実施記録のPRのマージ後にしか確認できないため、結果は次に`main`へ取り込むPR（次の作業単位等）で本一覧に追記する
- No.7〜9の`dbt build`は、`sample_data/`のダミーCSVを取り込んだ`RAW_DEV`に対して実施する

### 本一覧の対象外とするもの
| 内容 | 扱い |
|---|---|
| 承認画面に、何のリリースか（契機のマージ・手動実行者）が表示されること | 依頼者がリリース手順書の受け入れテストで確認する |
| 新しいデータの取り込み後、手動実行と承認のみでmartに新しいデータが反映されること（要件定義書の完了条件） | 実データの取り込みを伴うため、依頼者がリリース手順書の受け入れテストで確認する。仕組みとしてmartが作り直されることは、No.15で確認する |
| 失敗時のメール通知が実際に届くこと | PRODでわざと失敗させることは避ける。GitHubの標準機能のためテストの対象外とし、失敗がジョブの失敗として扱われる定義であること（No.4）までを確認する。成功時は通知せず、Actionsの画面で確認する（基本設計書「リリースの結果の確認」） |
| 承認がボタン操作であること、承認待ちが30日で取り消されること、承認前・PRのCIからEnvironmentのSecretsを読めないこと | GitHubの仕様のためテストの対象外とする |
| 秘密鍵をローカルから削除すること | リリース手順書の手順として依頼者が行う |
| stagingのテストが失敗した場合にmartを作り直さないこと | `dbt build`は、失敗したテストの対象（sourceかstagingか）によらず、その下流を同じ仕組みで飛ばす。sourceの場合（No.8）の確認で代える |

## マージ前

| No. | テスト区分 | 対象要件 | 確認内容 | 期待結果 | 対応テスト名（任意） | 実施結果 | 実施日 |
|---|---|---|---|---|---|---|---|
| 1 | 単体 | 基本設計書「作るもの」（CDのワークフロー） | ワークフローの定義の文法を、GitHub Actionsの定義チェックツール（actionlint）で確認する | エラー・警告が0件 |  | PASS | 2026-10-18 |
| 2 | 単体 | 要件定義書「リリースの契機」／基本設計書「リリースの契機」 | ワークフローの起動条件の定義を確認する。`dbt/**`・`requirements.txt`の変更による起動は、本作業のPRにそれらの変更が無いため、マージ後に実際に動かしては確認せず、本ケースの定義の確認で代える | `main`へのpushで、`dbt/**`・`requirements.txt`・`.github/workflows/dbt-release.yml`のいずれかに変更があった場合のみ起動する定義になっている。手動実行（`workflow_dispatch`）が定義されている |  | PASS | 2026-10-18 |
| 3 | 単体 | 要件定義書「リリースの承認」／基本設計書「リリースの承認」 | ワークフローの定義と、GitHubのEnvironment `prod`の設定を確認する（GitHubのAPIで設定を読み取る） | dbtを実行するジョブがEnvironment `prod`を指定している。`prod`の承認者が`tomitayuuki`、実行を許可するブランチが`main`のみ。`concurrency`の`group`が固定値で、`cancel-in-progress`が`false`（実行中のリリースは途中で止めない） |  | PASS | 2026-10-18 |
| 4 | 単体 | 要件定義書「リリースの結果」（成功・失敗が分かる）／基本設計書「リリースの処理」・「GitHubに登録する値」 | ワークフローの処理の定義を確認する | 承認後に、Python 3.13の用意→`requirements.txt`からの導入→秘密鍵の一時ファイルへの書き出し→`dbt build --target prod`の順で実行する。秘密鍵の一時ファイルは、成功・失敗にかかわらず削除する定義になっている。接続情報は`SNOWFLAKE_ACCOUNT`・`SNOWFLAKE_PRIVATE_KEY`（Secret）とユーザー名`SVC_DBT_PROD`から渡している。`dbt build`のステップに`continue-on-error`・`\|\| true`等が無く、dbtの失敗がジョブの失敗として扱われる |  | PASS | 2026-10-18 |
| 5 | 単体 | 基本設計書「Actionsのログの公開範囲」 | ワークフローの定義を確認する | `target/`等の実行結果のファイルを成果物としてアップロードする処理が無い。秘密鍵・アカウント識別子をログに出力する処理（`echo`等）が無い |  | PASS | 2026-10-18 |
| 6 | 単体 | 基本設計書「リリースの処理」（既存の`profiles.yml`の`prod`をそのまま使う） | 接続用の環境変数にダミーの値を設定したうえで、ローカルで`dbt ls --target prod --resource-type model source --output json --output-keys unique_id database schema`を実行する（Snowflakeに接続しないため、PRODへのアクセスは発生しない）。`git diff main -- dbt/profiles.yml`を確認する | sourceが`RAW_PROD`.`MONEYFORWARD`、stagingモデルが`ANALYTICS_PROD`.`STAGING`、martsモデルが`ANALYTICS_PROD`.`MARTS`となる。`git diff`の結果が空 |  | PASS | 2026-10-18 |
| 7 | 結合 | 基本設計書「リリースの処理」（`dbt build`） | ローカルで、正常なダミーデータに対して`dbt build --target dev`を実行する | すべてのモデル・テストが成功する（エラー0件・スキップ0件）。`ANALYTICS_DEV.MARTS.MART_TRANSACTIONS`の件数が8件 |  | PASS | 2026-10-18 |
| 8 | 結合 | 要件定義書「リリースの結果」（上流で異常が見つかった場合はmartを前回の状態のまま残す）／基本設計書「リリースの処理」 | 前提として、`dbt/dbt_project.yml`で`marts`のmaterializationが`table`であること（viewだとRAWの変更がそのまま見えるため）を確認する。No.7の後、`RAW_DEV`の取引テーブルに既存の行と同じ`ID`の行を1件追加し、`dbt build --target dev`を実行する。実行前後で`MART_TRANSACTIONS`の件数と、`ANALYTICS_DEV.INFORMATION_SCHEMA.TABLES`の`LAST_ALTERED`を比較する。確認後、追加した行を削除し、`dbt build --target dev`で元の状態に戻す | `marts`のmaterializationが`table`。sourceの一意性のテストが失敗し、`dbt build`が失敗で終わる。下流の`stg_moneyforward__transactions`・`mart_transactions`の作成と、それらのテストがスキップされる。`MART_TRANSACTIONS`の件数（8件）・`LAST_ALTERED`が実行前と変わらない。後始末の後、No.7と同じ結果になる |  | PASS | 2026-10-18 |
| 9 | 結合 | 基本設計書「Actionsのログの公開範囲」 | No.8の失敗時の`dbt build`の出力に、取引の内容が含まれていないかを確認する | 出力に、ダミーデータの取引の内容（`sample_shop`等の内容列の値・金額）が含まれない |  | PASS | 2026-10-18 |
| 10 | 総合 | 要件定義書「リリースの手順」（決まった手順が永続ドキュメントに記載されている。dbtのみのリリースでは手順書を作らない。dbt以外の本番作業では手順書を作る） | `docs/development-standards.md`・`CLAUDE.md`の記載を確認する | `docs/development-standards.md`に、承認・手動実行・結果の確認・失敗時の対応・受け入れテストの記録先が記載されている。5.6・`CLAUDE.md`のリリース手順書の作成条件が、dbtのリリースのみの場合は不要、dbt以外の本番作業がある場合は必要、となっている。5.1に、リリース手順書が無い場合の「受け入れテストの結果」の章が追加されている。`CLAUDE.md`の開発フローのステップ9が、CDによるリリースの承認を含む形に更新されている |  | PASS | 2026-10-18 |
| 11 | 総合 | 要件定義書「スコープ」（取り込みに連動した自動実行を課題一覧表に記載する）／基本設計書「永続ドキュメントへの反映」 | `docs/architecture.md`・`docs/repository-structure.md`・`docs/backlog.md`の記載を確認する | `docs/architecture.md`に、CDによるdbtの実行（全体構成図・技術スタック・データフロー）、`SVC_DBT_PROD`（`TRANSFORMER_PROD`のみ）と「人が使うユーザーは1つ、CD用のサービスユーザーを別に持つ」方針、`SVC_DBT_PROD`の秘密鍵の区分が記載されている。`docs/repository-structure.md`にCDのワークフローが記載されている。`docs/backlog.md`で022が対応中（初回リリース後、実施記録のPRでクローズする旨を記載）となり、取り込みに連動したdbtの自動実行の課題が起票されている |  | PASS | 2026-10-18 |

## マージ後

| No. | テスト区分 | 対象要件 | 確認内容 | 期待結果 | 対応テスト名（任意） | 実施結果 | 実施日 |
|---|---|---|---|---|---|---|---|
| 12 | 総合 | 要件定義書「リリースの契機」（dbtに関係する資材のマージで始まる）・「リリースの承認」（承認するまでPRODに反映されない） | 本作業のPR（`.github/workflows/dbt-release.yml`を含む）のマージ後、ワークフローの実行状況を確認する | ワークフローが起動し、承認待ちで止まっている。dbtを実行するジョブが始まっていない |  |  |  |
| 13 | 結合 | 基本設計書「CD専用のSnowflakeユーザー」 | 依頼者がユーザーを作成した後、`SHOW GRANTS TO USER SVC_DBT_PROD`・`DESC USER SVC_DBT_PROD`で、ユーザーの設定を確認する（読み取りのみ） | 付与されたロールが`TRANSFORMER_PROD`のみ。`TYPE`が`SERVICE`、`DEFAULT_ROLE`が`TRANSFORMER_PROD`、`DEFAULT_WAREHOUSE`が`MAIN_WH`、`HAS_PASSWORD`が`false`、`RSA_PUBLIC_KEY_FP`が設定されている |  |  |  |
| 14 | 総合 | 要件定義書「リリースの結果」（成功が依頼者に分かる）／基本設計書「リリースの処理」・「CD専用のSnowflakeユーザー」・「Actionsのログの公開範囲」 | 依頼者がNo.12の承認待ちを承認した後、実行結果とログを確認する。PRODの`MART_TRANSACTIONS`の`LAST_ALTERED`を、`ANALYTICS_PROD.INFORMATION_SCHEMA.TABLES`で確認する（読み取りのみ） | 実行が成功で終わる。ログ上、`target`が`prod`で、すべてのモデル・テストが成功している。`LAST_ALTERED`が承認後の時刻になっている（ワークフローが渡す認証情報は`SVC_DBT_PROD`のもののみのため（No.4）、成功したことで`SVC_DBT_PROD`で接続できたことも確認できる）。ログに秘密鍵・アカウント識別子が表示されず（伏せ字）、取引の内容（内容列の値・金額）も表示されていない |  |  |  |
| 15 | 総合 | 要件定義書「リリースの契機」（資材の変更が無くても手動で始められる） | 依頼者が`main`を指定して手動実行し、承認した後、実行結果と`MART_TRANSACTIONS`の`LAST_ALTERED`を確認する | 手動実行が承認待ちで止まり、承認後に成功で終わる。`LAST_ALTERED`が承認後の時刻に更新されている |  |  |  |
| 16 | 総合 | 要件定義書「リリースの承認」（承認するまでPRODに反映されない）／基本設計書「概要」（却下すると何もせず終了する）・「リリースの承認」（同時に1つだけ動かす） | 依頼者が`main`を指定して手動実行を2回続けて行い、2件の実行の状態を確認する。その後、承認待ちの実行を却下し、残った実行も承認待ちになったら却下する。実行結果と`MART_TRANSACTIONS`の`LAST_ALTERED`を確認する | 1件目が承認待ち、2件目がその後ろで待っている（基本設計書の記述と異なる場合は、実際の挙動を記録し、実施記録のPRで基本設計書・`docs/development-standards.md`4.5.3を修正する）。却下したジョブはdbtを実行せずに終わる（却下として記録される）。`LAST_ALTERED`がNo.15から変わらない |  |  |  |
| 17 | 総合 | 基本設計書「リリースの契機」（`main`以外のブランチの手動実行は拒否する） | 実施記録のPR用のブランチ（マージ後の`main`から作るため、ワークフローの定義を含む）を指定して手動実行し、実行結果を確認する | Environment `prod`の制限（実行を許可するブランチ）によりジョブが拒否され、承認待ちにならず、dbtは実行されない。`LAST_ALTERED`がNo.16から変わらない |  |  |  |
| 18 | 総合 | 要件定義書「リリースの契機」（dbtに関係しない資材のマージでは始まらない） | 実施記録のPR（`.steering/`配下のみの変更）のマージ後に、ワークフローの実行状況を確認する | ワークフローが起動していない |  |  |  |

## 実施結果の補足

### No.1
- actionlint v1.7.12（Windows版の実行ファイルを一時的に取得して使用）で、出力なし・終了コード0

### No.3
- Environment `prod`は、実装タスク2でGitHubのAPIにより作成した。読み取り結果：承認者（`required_reviewers`）が`tomitayuuki`、実行を許可するブランチ（`deployment_branch_policy`）が`custom_branch_policies`で、許可するブランチは`main`（`type: branch`）の1件のみ

### No.6
- 実行結果：`mart_transactions`が`ANALYTICS_PROD`.`marts`、`stg_moneyforward__transactions`が`ANALYTICS_PROD`.`staging`、sourceが`RAW_PROD`.`moneyforward`（Snowflake上では大文字の`MARTS`等として解決される）。`git diff main -- dbt/profiles.yml`の出力は0行

### No.7〜9
- No.7：`dbt build --target dev`の結果は`PASS=16 WARN=0 ERROR=0 SKIP=0`。`MART_TRANSACTIONS`は8件
- No.8：`RAW_DEV.MONEYFORWARD.TRANSACTIONS`に、`ID = 'DUMMY-0000000003'`の行を複製して1件追加した（9件）。`dbt build --target dev`は終了コード1で、結果は`PASS=5 ERROR=1 SKIP=10`
    - 失敗：`source_unique_moneyforward_transactions_id`（`FAIL 1`）
    - スキップ：`stg_moneyforward__transactions`・`mart_transactions`と、それらのテスト・unit test
    - `MART_TRANSACTIONS`は実行前後とも8件。`LAST_ALTERED`は直前の正常な実行時刻のままで、変わらなかった
- 後始末：`DUMMY-0000000003`の2行を削除し、1行を戻した（8件・IDの重複なし）。再度の`dbt build --target dev`で`PASS=16`、`MART_TRANSACTIONS`は8件
- No.9：No.8の`dbt build`の出力（39行）に、`sample_`・`DUMMY-`・金額（`9999`・`300000`）・大項目（`食費`・`収入`）を含む行は0件。失敗したテストについても、出力されるのは`FAIL 1`（件数）までだった
