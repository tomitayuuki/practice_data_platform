# リリース手順書

## 概要
- CD（`.github/workflows/dbt-release.yml`）を本番運用に乗せる。CDがPRODへ接続するためのSnowflakeユーザー`SVC_DBT_PROD`の作成と、GitHubへの秘密情報の登録を行い、本作業のPRのマージで起動したリリースを承認して、最初のCDによるリリースを行う
- あわせて、手動実行・却下・`main`以外のブランチの手動実行の動きを確認し（テストケース一覧No.12〜17）、受け入れテストを行う
- 実施タイミング：本作業のPRが`main`にマージされた後。マージ後、CDは承認待ちで止まっているため、手順3〜5を承認待ちの間に行ってから承認する
- 所要時間の目安：40〜60分（新しいデータの取り込みを含む）

## 実施者の分担
| 手順 | 実施者 | 理由 |
|---|---|---|
| 1. 前提の確認 | Claude | ローカル・GitHubの状態の確認のみで、PRODへの書き込みを伴わない |
| 2. キーペアを作成する | ユーザー | 秘密鍵を扱う（Claudeは秘密鍵を読まない・扱わない） |
| 3. `SVC_DBT_PROD`を作成する | ユーザー | PRODのSnowflakeアカウントへの変更を伴う |
| 4. ユーザーの設定を確認する | Claude | 読み取りのみ（`SHOW`・`DESC`） |
| 5. GitHubに秘密情報を登録し、ローカルの秘密鍵を削除する | ユーザー | 秘密鍵を扱う |
| 6. マージで起動したリリースを承認する | ユーザー | PRODへの書き込みを伴う（承認の操作） |
| 7. 新しいデータを取り込み、手動実行でリリースする | ユーザー | PRODへの書き込みと、実データの取り扱いを伴う |
| 8. 承認待ちを却下する | ユーザー | リリースの操作 |
| 9. `main`以外のブランチで手動実行する | Claude（ブランチの作成）・ユーザー（手動実行） | ブランチの作成はPRODに影響しない。実行の操作はユーザーが行う |
| 10. 受け入れテスト | ユーザー | 実データの参照を伴う |

- 手順4・6〜9の各手順の後、Claudeが実行結果（GitHubの実行状況・ログ、PRODの`MART_TRANSACTIONS`の最終更新日時）を読み取りのみで確認し、テストケース一覧の該当するケースの結果をユーザーに報告する

## 注意事項
- 手順は上から順に実施する。いずれかの手順で期待結果と異なった場合は、その時点で中断し「失敗した場合の対応」に従う
- コマンドはすべて**PowerShell**で、リポジトリ直下（`C:\Users\tomit\Documents\practice_data_platform`）から実行する前提で記載している
- 秘密鍵の中身は、画面に表示しない・チャットに貼り付けない。本手順書のコマンドは、秘密鍵の中身を画面に表示しない形にしてある
- 手順書に無い作業が必要になった場合は、`docs/development-standards.md`5.6に従う（PRODに変更を伴う作業はその場で中断する。ローカルの作業は実施して実施記録に残す）

## 手順

### 1. 前提の確認（実施者：Claude）

**1-1. `main`を最新化する**
```powershell
git switch main
git pull
git log --oneline -1
```
- 期待結果：最新のコミットが本作業のPR（CDによるdbtリリースの自動化）のsquashマージになっている

**1-2. CDが承認待ちで止まっていることを確認する（テストケース一覧No.12）**
```powershell
gh run list --workflow dbt-release.yml --limit 3
```
- 期待結果：本作業のマージを契機とした実行が1件あり、状態が`waiting`（承認待ち）になっている

**1-3. Environment `prod`の設定を確認する**
```powershell
gh api repos/tomitayuuki/practice_data_platform/environments/prod --jq '[.protection_rules[] | {type, reviewers: [.reviewers[]?.reviewer.login]}]'
```
- 期待結果：`required_reviewers`の承認者が`tomitayuuki`、`branch_policy`がある

- Claudeは、手順1-1〜1-3の結果をユーザーに報告する。以降は分担の表に従う

### 2. キーペアを作成する（実施者：ユーザー）

**2-1. 秘密鍵と公開鍵を作成する**
```powershell
$openssl = 'C:\Program Files\Git\usr\bin\openssl.exe'
$keyDir = "$env:USERPROFILE\.snowflake\keys"
& $openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$keyDir\svc_dbt_prod_key.p8"
& $openssl pkey -in "$keyDir\svc_dbt_prod_key.p8" -pubout -out "$keyDir\svc_dbt_prod_key.pub"
```
- 期待結果：エラーが表示されず、`$keyDir`に`svc_dbt_prod_key.p8`（秘密鍵）と`svc_dbt_prod_key.pub`（公開鍵）が作成される
- 個人ユーザーの既存の鍵（`snowflake_key.p8`）とは別のファイル名にしてあるため、既存の鍵は上書きされない

**2-2. 公開鍵の値を表示する**
```powershell
(Get-Content "$keyDir\svc_dbt_prod_key.pub" | Where-Object { $_ -notmatch '-----' }) -join ''
```
- 期待結果：`MIIB`で始まる1行の文字列が表示される。手順3で使うためコピーする（公開鍵は秘密ではない）

### 3. `SVC_DBT_PROD`を作成する（実施者：ユーザー）
Snowsightのワークシートで、以下を実行する（`<公開鍵>`は手順2-2でコピーした文字列に置き換える）。

```sql
USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS SVC_DBT_PROD
    TYPE = SERVICE
    DEFAULT_ROLE = TRANSFORMER_PROD
    DEFAULT_WAREHOUSE = MAIN_WH
    RSA_PUBLIC_KEY = '<公開鍵>'
    COMMENT = 'CD（GitHub Actions）によるdbtのPRODリリース用（.steering/20261012-dbt-cd）';

GRANT ROLE TRANSFORMER_PROD TO USER SVC_DBT_PROD;
```
- 期待結果：`User SVC_DBT_PROD successfully created.`、`Statement executed successfully.`と表示される

### 4. ユーザーの設定を確認する（実施者：Claude、テストケース一覧No.13）
```powershell
snow sql -q "SHOW GRANTS TO USER SVC_DBT_PROD; DESC USER SVC_DBT_PROD"
```
- 期待結果：付与されたロールが`TRANSFORMER_PROD`のみ。`TYPE`が`SERVICE`、`DEFAULT_ROLE`が`TRANSFORMER_PROD`、`DEFAULT_WAREHOUSE`が`MAIN_WH`、`HAS_PASSWORD`が`false`、`RSA_PUBLIC_KEY_FP`が設定されている

### 5. GitHubに秘密情報を登録し、ローカルの秘密鍵を削除する（実施者：ユーザー）

**5-1. 秘密鍵とアカウント識別子を、Environment `prod`のSecretsに登録する**
登録する前に、登録元の値が空でないことを確認する（値そのものは表示しない）。
```powershell
[bool][Environment]::GetEnvironmentVariable('SNOWFLAKE_ACCOUNT', 'User'); Test-Path "$keyDir\svc_dbt_prod_key.p8"
```
- 期待結果：`True`が2つ表示される。`False`がある場合は、登録せずに中断する

```powershell
Get-Content "$keyDir\svc_dbt_prod_key.p8" -Raw | gh secret set SNOWFLAKE_PRIVATE_KEY --env prod --repo tomitayuuki/practice_data_platform
[Environment]::GetEnvironmentVariable('SNOWFLAKE_ACCOUNT', 'User') | gh secret set SNOWFLAKE_ACCOUNT --env prod --repo tomitayuuki/practice_data_platform
```
- 期待結果：それぞれ`✓ Set Actions secret ... for tomitayuuki/practice_data_platform`と表示される（値は表示されない）

**5-2. 登録されたことを確認する**
```powershell
gh secret list --env prod --repo tomitayuuki/practice_data_platform
```
- 期待結果：`SNOWFLAKE_ACCOUNT`・`SNOWFLAKE_PRIVATE_KEY`の2件が表示される（名前と更新日時のみ）

**5-3. ローカルの秘密鍵を削除する**
```powershell
Remove-Item "$keyDir\svc_dbt_prod_key.p8"
Test-Path "$keyDir\svc_dbt_prod_key.p8"
```
- 期待結果：`False`と表示される
- 秘密鍵はGitHubのSecretsにのみ残る。作り直しが必要になった場合は、手順2から作り直し、`ALTER USER SVC_DBT_PROD SET RSA_PUBLIC_KEY = '<新しい公開鍵>'`で登録し直す

### 6. マージで起動したリリースを承認する（実施者：ユーザー、テストケース一覧No.14）
1. GitHubのリポジトリの「Actions」タブを開き、「dbt Release (PROD)」の承認待ちの実行を開く
2. 画面上部の「Review deployments」を押す
3. **承認画面に、本作業のPRのマージ（コミット）を契機とした実行であることが表示されていることを確認する**（受け入れテストの一部）
4. `prod`にチェックを入れ、「Approve and deploy」を押す
- 期待結果：ジョブが始まり、数分で成功（緑のチェック）で終わる。`dbt build`のステップの最後に`Done. PASS=16 WARN=0 ERROR=0 SKIP=0`と表示される

### 7. 新しいデータを取り込み、手動実行でリリースする（実施者：ユーザー、テストケース一覧No.15）
`docs/development-standards.md`4.5の手順（取り込み後の作り直し）に沿って行う。

**7-1. 取り込み前の件数を確認する**
Snowsightのワークシートで、ロールを`REPORTER_PROD`に切り替えて以下を実行し、件数を控える。
```sql
select count(*) from ANALYTICS_PROD.MARTS.MART_TRANSACTIONS;
```

**7-2. 新しいデータを取り込む**
- マネーフォワードMEから、まだ取り込んでいない取引を含む期間（例：今月）の「収入・支出詳細」のCSVをエクスポートし、リポジトリ外に保存する
```powershell
.\ingestion\upload_and_load_moneyforward.ps1 -CsvPath "C:\Users\tomit\Downloads\<エクスポートしたファイル名>.csv" -Env prod
```
- 期待結果：最後に`Done: transactions_<日時>.csv loaded into the prod environment.`と表示される
- この時点では、martは作り直されていない（手順7-1と同じ件数のまま）

**7-3. 手動実行して承認する**
1. 「Actions」タブ →「dbt Release (PROD)」→「Run workflow」を押す
2. 「Use workflow from」が`main`になっていることを確認し、「Run workflow」を押す
3. 起動した実行を開き、「Review deployments」から`prod`を承認する（手順6と同じ）
- 期待結果：承認待ちで止まり、承認後に成功で終わる

**7-4. 取り込み後の件数を確認する**
```sql
select count(*) from ANALYTICS_PROD.MARTS.MART_TRANSACTIONS;
```
- 期待結果：手順7-1から、手順7-2で新しく取り込んだ取引の件数だけ増えている（受け入れテストの一部）

### 8. 続けて手動実行し、承認待ちを却下する（実施者：ユーザー、テストケース一覧No.16）
1. 手順7-3の1〜2と同じく、`main`で手動実行する。1件目が起動したら、続けてもう1回手動実行する
2. 「Actions」タブで2件の実行の状態を確認し、Claudeに伝える（Claudeも読み取りで確認する）
3. 承認待ちの実行を開き、「Review deployments」で`prod`にチェックを入れ、「Reject」を押す
4. もう1件の実行が承認待ちになったら、同じく「Reject」を押す（既に終わっている場合は不要）
- 期待結果：1件目が承認待ち、2件目がその後ろで待っている。却下したジョブはdbtを実行せずに終わる

### 9. `main`以外のブランチで手動実行する（テストケース一覧No.17）
**9-1. 実施記録用のブランチを作成する（実施者：Claude）**
- Claudeが、マージ後の`main`から実施記録用のブランチ（`feature/20261012-dbt-cd-release-record`）を作成してpushし、ユーザーにブランチ名を伝える

**9-2. そのブランチを指定して手動実行する（実施者：ユーザー）**
1. 「Actions」タブ →「dbt Release (PROD)」→「Run workflow」を押す
2. 「Use workflow from」で手順9-1のブランチを選び、「Run workflow」を押す
- 期待結果：承認待ちにならず、Environment `prod`の制限によりジョブが失敗（拒否）で終わる。dbtは実行されない

### 10. 受け入れテスト（実施者：ユーザー）
要件定義書の完了条件と対応させて確認する。

| 完了条件 | 確認方法 |
|---|---|
| dbtに関係する資材を変更したPRのマージ後、承認の操作のみでリリースが完了すること | 手順6で、承認画面に契機のマージが表示され、承認のみで成功したこと |
| dbtに関係しない資材のみを変更したPRのマージでは、リリースが始まらないこと | 実施記録のPR（`.steering/`配下のみの変更）のマージ後に、「Actions」タブの「dbt Release (PROD)」に新しい実行が増えていないこと（実施記録のPRのマージ後に確認し、結果は次に`main`へ取り込むPRで記録する） |
| 新しいデータの取り込み後、手動実行と承認のみでmartに新しいデータが反映されること | 手順7-4で件数が増えたこと |
| dbtのリリースの手順が永続ドキュメントに記載され、それを見てリリースを行えること | 手順7を、`docs/development-standards.md`4.5を見て迷わず行えたこと |

以上でリリースは完了。

## 失敗した場合の対応
- 実施した手順の番号と、表示されたエラーメッセージ（GitHubのActionsのログを含む）をClaudeに共有する
- **共有する前に、エラーメッセージに取引の内容（店名・金額・メモ等）や秘密鍵の中身が含まれていないかを確認し、含まれている場合はその部分を伏せる**（dbtのテスト失敗の表示は件数のみで、取引の内容は通常含まれない）
- 手順2・5で失敗した場合：作成途中の鍵ファイルを削除し、手順2からやり直す
- 手順3で失敗した場合：エラーの内容をClaudeに共有する。`SVC_DBT_PROD`が中途半端に作成された場合は、`DROP USER SVC_DBT_PROD;`で削除してから手順3をやり直す
- 手順6・7でジョブが失敗した場合：`dbt build`で失敗したテストより下流のmartは作り直されず、前回の状態のまま残る。接続エラー（認証の失敗等）の場合は、手順3〜5の設定を見直してから、手順7-3と同じ手動実行でやり直す。データやモデルの異常の場合は、原因を修正したPRをマージしてリリースし直す
- 承認待ちの実行は、承認・却下しない限り30日で自動的に取り消されるため、中断して後日再開してもよい（再開時は手順7-3の手動実行でリリースする）

## 実施記録
| 実施日 | 手順 | 実施者 | 結果 | 備考 |
|---|---|---|---|---|
| 2026-10-18 | 1・4・9-1 | Claude | 完了 | 手順4はテストケース一覧No.13がPASS。手順6〜9の結果確認（No.12・14〜17）もすべてPASS |
| 2026-10-18 | 2〜3・5〜8・9-2・10 | ユーザー | 完了 | 手順5-1は、コマンドが1行に連結されて`SNOWFLAKE_ACCOUNT`の登録が失敗したため、1行ずつ実行し直して登録した。手順7で新しいデータの取り込み後にmartの件数が増えたことを確認。手順10の受け入れテストは、完了条件1・3・4がOK（`docs/development-standards.md`4.5の記載どおりに作業できた）。完了条件2は、本実施記録のPRのマージ後に確認する |
