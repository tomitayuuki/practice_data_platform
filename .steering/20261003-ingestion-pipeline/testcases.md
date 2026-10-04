# テストケース一覧

様式は`docs/development-standards.md`5章に従う。

| No. | 対象要件 | 確認内容 | 期待結果 | 対応テスト名（任意） | 実施結果 | 実施日 |
|---|---|---|---|---|---|---|
| 1 | 要件定義書「要件」1項目・受け入れ基準1 | `sample_data/`のダミーCSVを使い、`upload_and_load_moneyforward.ps1 -Env dev`を実行する | S3の`inbox`へアップロードされ、Snowflakeへの取り込みが成功し、`RAW_DEV.MONEYFORWARD.TRANSACTIONS`にCSVと同じ件数のレコードが登録される。処理後、ファイルは`inbox`から`archive`へ移動している | | PASS | 2026-10-04 |
| 2 | 要件定義書「要件」2項目（Shift-JIS） | 取り込まれたレコードのうち、日本語を含む列（`description`・`institution_name`・`category_major`・`category_minor`・`memo`）の値を確認する | 文字化けせず、元CSVの日本語の値がそのまま格納されている | | PASS | 2026-10-04 |
| 3 | 要件定義書「要件」3項目・受け入れ基準2（重複排除・通常の再実行） | 同じCSV（同じ`id`群）をもう一度アップロード・取り込みする | 2回目の`MERGE`挿入件数は0件。`TRANSACTIONS`の行数は1回目から変化しない | | PASS | 2026-10-04 |
| 4 | 要件定義書「要件」3項目（重複排除・STG側に同一`id`が複数行あるケース。CIレビューで判明した不具合の再現確認） | `inbox`に同一`id`を含む未処理ファイルを2つ置いた状態で、取り込みSQLを実行する | `TRANSACTIONS_STG`には2行入るが、`QUALIFY ROW_NUMBER()`で一意化され、`TRANSACTIONS`には該当`id`が1行のみ挿入される | | PASS | 2026-10-04 |
| 5 | 基本設計書「列名マッピング」 | 取り込まれたレコードの各列が、設計書の対応表（`is_target`/`transaction_date`/`description`/`amount`/`institution_name`/`category_major`/`category_minor`/`memo`/`is_transfer`/`id`）通りにマッピングされているか確認する | 全列が対応表通りに格納されている | | PASS | 2026-10-04 |
| 6 | 基本設計書「未確定事項」（日付・真偽値の型変換） | `transaction_date`列がDATE型として、`is_target`・`is_transfer`列がBOOLEAN型として正しく変換されているか確認する | 日付が正しい値のDATE型、真偽値が正しいBOOLEAN型で格納されている | | PASS | 2026-10-04 |
| 7 | 要件定義書「要件」4項目（実データ不使用） | 今回のテストで使用したCSVが`sample_data/`配下のダミーデータであることを確認する。リポジトリに実データが含まれていないか確認する | マネーフォワードの実データがgit管理下に存在しない | | PASS | 2026-10-04 |
| 8 | 要件定義書「要件」5項目（認証情報の非管理） | AWS CLI認証情報・Snowflakeの秘密鍵等がリポジトリに含まれていないか確認する | 認証情報ファイルがgit管理対象外になっている | | PASS（ただし補足あり） | 2026-10-04 |
| 9 | 要件定義書「スコープ」（PROD/DEV環境分離） | DEV環境への取り込みが`RAW_PROD`側に影響しないことを確認する | `RAW_DEV`への取り込み前後で`RAW_PROD.MONEYFORWARD.TRANSACTIONS`の件数・内容に変化がない | | PASS | 2026-10-04 |
| 10 | 基本設計書「実装後のCIレビューで判明した不具合と対応」（失敗時のinbox後始末） | Snowflakeへの取り込みが失敗するケースを作り、`upload_and_load_moneyforward.ps1`を実行する | スクリプトがエラーで停止し、アップロード済みファイルがS3の`inbox`から削除される（残留しない） | | PASS | 2026-10-04 |
| 11 | 要件定義書「スコープ」（`RAW_PROD`・`RAW_DEV`両対応。サブエージェントレビューでの指摘） | **環境構築時の一回限りの確認。実施者はユーザー（Claudeは本番環境を直接操作しない）。** `sample_data/`のダミーCSVを使い、`upload_and_load_moneyforward.ps1 -Env prod`を実行する | S3の`inbox`（prod）へアップロードされ、Snowflakeへの取り込みが成功し、`RAW_PROD.MONEYFORWARD.TRANSACTIONS`にCSVと同じ件数のレコードが登録される。処理後、ファイルは`inbox`から`archive`へ移動している | | PASS | 2026-10-04 |
| 12 | 基本設計書122行目「既存の`id`は内容が変わっても更新しない」（サブエージェントレビューでの指摘） | 既存の`id`（ケース1で登録済み）はそのままに、他の列（金額等）を変更したCSVを再取り込みする | `MERGE`の挿入件数は0件。`TRANSACTIONS`側の値は元のまま変化しない（新しい値で上書きされない） | | PASS | 2026-10-04 |
| 13 | 基本設計書129-130行目「アップロード時にASCIIの日時ベース名に変換」（サブエージェントレビューでの指摘） | `archive`配下にアップロード済みのファイルのキー名を確認する | ファイル名が`transactions_<YYYYMMDDHHMMSS>.csv`形式（ASCII）になっている | | PASS | 2026-10-04 |
| 14 | 基本設計書「IAMロール・ポリシー」「外部ステージの利用権限」（PROD/DEVの権限分離。サブエージェントレビューでの指摘） | `SHOW GRANTS ON STAGE`等で、PROD用・DEV用の外部ステージの利用権限（`USAGE`）がそれぞれ`LOADER_PROD`・`LOADER_DEV`のみに付与されているか確認する | PROD用ステージは`LOADER_PROD`のみ、DEV用ステージは`LOADER_DEV`のみに`USAGE`権限が付与されている | | PASS | 2026-10-04 |
| 15 | 基本設計書「IAMロール・ポリシー」（PROD/DEVのS3アクセス範囲が実際に分離されているか。ポリシー文面の確認ではなく、実際の操作可否で検証） | `RAW_PROD_S3_INTEGRATION`で`dev/`配下に、`RAW_DEV_S3_INTEGRATION`で`prod/`配下に、それぞれ一時ステージの作成と`LIST`を試みる。また`RAW_PROD_S3_INTEGRATION`で自分自身の`prod/`配下への一時ステージの作成と`LIST`も試みる | 相手環境の配下へは、いずれも一時ステージの**作成時点**で`STORAGE_ALLOWED_LOCATIONS`違反によりエラーになる（`LIST`まで到達しない）。自分自身の配下へは、ステージ作成・`LIST`ともにエラーにならない | | PASS | 2026-10-04 |

## 実施結果の補足

- **ケース1**：CSV1件に対し`RAW_DEV.MONEYFORWARD.TRANSACTIONS`へ1件登録、`inbox`→`archive`への移動も確認。
- **ケース2・5・6**：取り込まれた行を確認。`is_target=True`／`transaction_date=1900-01-01`（DATE型）／`description=sample_shop`／`amount=9999`／`institution_name=sample_bank`／`category_major=XX費`（日本語、文字化けなし）／`category_minor=XXXX`／`memo=`（空）／`is_transfer=False`／`id`一致。設計書の対応表通り。
- **ケース3**：同一`id`のCSVを再取り込みし、`MERGE`の挿入件数が0件になることを確認。
- **ケース4**：`inbox`に同一`id`（テスト専用ダミーID）を含むファイルを2つ置いた状態で取り込みを実行。`TRANSACTIONS_STG`は2行になったが、`TRANSACTIONS`への挿入は1行のみ。確認後、テスト用データ（S3ファイル・Snowflakeの行）は削除済み。
- **ケース7**：`git ls-files "*.csv"`で、リポジトリ内の全CSVが`sample_data/`のダミーファイル1件のみであることを確認。
- **ケース8**：リポジトリ内（`.git`除く）に`*.pem`/`*.p8`/`connections.toml`/`credentials`に該当するファイルが存在しないことを確認。Snowflakeの秘密鍵・AWS認証情報は、実体がそもそもリポジトリ外（ユーザーのホームディレクトリ）にあるため、今回の構成では漏洩リスクは無い。
    - **補足（課題候補）**：ただし、リポジトリに`.gitignore`が存在しない。認証情報の実害は無いが、今後誤って認証情報ファイルをリポジトリ内に作成してしまった場合に防ぐ仕組みが無い状態。`docs/backlog.md`への追加を別途検討する。
- **ケース9**：取り込み前後で`RAW_PROD.MONEYFORWARD.TRANSACTIONS`が0件のまま変化しないことを確認。
- **ケース10**：`load_moneyforward_transactions_dev.sql`の`FILE_FORMAT`参照を一時的に存在しないオブジェクト名に書き換えて意図的に失敗させ、スクリプトがエラー終了すること、アップロード済みファイルが`inbox`から削除されることを確認。確認後、SQLファイルは元の内容に復元済み（`git diff`で差分なしを確認）。
- **ケース11**：PRODへの書き込みはClaude Codeの自動モードにより「本番操作」としてブロックされたため（意図した挙動）、ユーザーが`!`経由で実行。CSV1件が`RAW_PROD.MONEYFORWARD.TRANSACTIONS`へ登録され、`inbox`→`archive`への移動も確認。確認後、ユーザーが`!`経由で`DELETE`を実行し、`RAW_PROD.MONEYFORWARD.TRANSACTIONS`はテスト前と同じ0件に戻した（PROD操作のためユーザー実施）。
- **ケース12**：既存`id`（ケース1の行）の金額・内容を変えたCSVを再取り込みし、`MERGE`の挿入件数が0件、値が元のまま（`amount=9999`／`description=sample_shop`）であることを確認。
- **ケース13**：`archive`配下の全ファイルが`transactions_<YYYYMMDDHHMMSS>.csv`形式であることを確認。
- **ケース14**：`SHOW GRANTS ON STAGE`で、PROD用ステージは`LOADER_PROD`のみ、DEV用ステージは`LOADER_DEV`のみに`USAGE`権限があることを確認。
- **ケース15**：ポリシーの文面ではなく実際の操作可否で検証。実施順序はケース11より前（この時点ではまだPRODに取り込み実績が無い）。`RAW_PROD_S3_INTEGRATION`で`dev/`配下に向けた一時ステージ作成は、作成時点で`STORAGE_ALLOWED_LOCATIONS`違反によりエラー（`LIST`までは到達しない）。`RAW_DEV_S3_INTEGRATION`で`prod/`配下に向けた一時ステージ作成も同様に、作成時点でエラー。`RAW_PROD_S3_INTEGRATION`で自分自身の`prod/`配下への一時ステージ作成・`LIST`はエラーにならず成功（`LIST`結果は`No data`だったが、これはこの時点でPRODにまだ取り込み実績が無かったためで、アクセス自体は許可されている。後のケース11実施後は取り込んだファイルが見える状態になっている）。このテストはユーザーが`!`経由で実行し、結果を確認した（Claudeは一時ステージ作成が「共有リソースの変更」として自動モードにブロックされたため）。一時ステージのためセッション終了で自動的に消滅し、後始末は不要。
