# リリース手順書（PROD初回リリース）

> **暫定版**：作業単位ドキュメントの様式（記載ルール）が未整備の状態で作成した（`docs/backlog.md` 023）。

## 概要
- 本作業単位で作成したdbtモデル（`stg_moneyforward__transactions`・`mart_transactions`）を、PROD環境（`ANALYTICS_PROD`）に初めて作成する
- PRODにはまだ実データが入っていないため、実データの取り込み（`RAW_PROD`）から行う
- 実施者：ユーザー（`CLAUDE.md`のデータ取扱いの原則により、ClaudeはPRODへの書き込みを行わない）
- 実施タイミング：本作業単位のPRが`main`にマージされた後
- 所要時間の目安：20〜30分

## 注意事項
- 手順は上から順に実施する。いずれかの手順で期待結果と異なった場合は、その時点で中断し「失敗した場合の対応」に従う
- コマンドはすべて**PowerShell**で、リポジトリ直下（`C:\Users\tomit\Documents\practice_data_platform`）から実行する前提で記載している
- 実データのCSVは、リポジトリ外（例：`Downloads`フォルダ）に保存する。リポジトリ内には置かない

## 手順

### 1. 前提の確認

**1-1. `main`を最新化する**
```powershell
git switch main
git pull
git log --oneline -1
```
- 期待結果：最新のコミットが本作業単位のPR（dbtモデリング）のsquashマージになっている

**1-2. 仮想環境とdbtを確認する**
```powershell
.\.venv\Scripts\dbt.exe --version
```
- 期待結果：`installed: 1.12.5`、`snowflake: 1.12.1`と表示される
- `.venv`が無い場合は、先に以下を実行する
```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

**1-3. 接続用の環境変数を確認する**
```powershell
$env:SNOWFLAKE_ACCOUNT; $env:SNOWFLAKE_USER; $env:SNOWFLAKE_PRIVATE_KEY_PATH
```
- 期待結果：3つとも値が表示される（開発時にユーザー環境変数として設定済み）
- 表示されない場合は、PowerShellを開き直してから再確認する

**1-4. PRODへのdbtの接続を確認する**
```powershell
cd dbt
..\.venv\Scripts\dbt.exe debug --target prod
cd ..
```
- 期待結果：最後に`All checks passed!`と表示される

### 2. 実データをRAW_PRODへ取り込む

**2-1. マネーフォワードMEから「収入・支出詳細」のCSVをエクスポートする**
- 取り込みたい期間（初回のため、可視化したい過去分すべて）を指定してエクスポートする
- 保存先はリポジトリ外（例：`C:\Users\tomit\Downloads\`）とする。ファイル名は変更しなくてよい

**2-2. 取り込みスクリプトを実行する**
```powershell
.\ingestion\upload_and_load_moneyforward.ps1 -CsvPath "C:\Users\tomit\Downloads\<エクスポートしたファイル名>.csv" -Env prod
```
- 期待結果：`Step 1/3`〜`Step 3/3`が順に表示され、最後に`Done: transactions_<日時>.csv loaded into the prod environment.`と表示される
- 途中で`LOADED_ROW_COUNT`等として取り込み件数が表示されるので、控えておく（手順4で使う）
- 複数のCSVに分けてエクスポートした場合は、ファイルごとに本手順を繰り返す（同じ取引が重複して取り込まれることは無い）

### 3. dbtをPRODで実行する

**3-1. モデルを作成する**
```powershell
cd dbt
..\.venv\Scripts\dbt.exe run --target prod
```
- 期待結果：`Concurrency: 4 threads (target='prod')`と表示され、最後に`Done. PASS=2 WARN=0 ERROR=0 SKIP=0`と表示される

**3-2. テストを実行する**
```powershell
..\.venv\Scripts\dbt.exe test --target prod
cd ..
```
- 期待結果：最後に`Done. PASS=14 WARN=0 ERROR=0 SKIP=0`と表示される

### 4. 結果を確認する
Snowsightのワークシートで、ロールを`REPORTER_PROD`に切り替えて以下を実行する。

**4-1. 件数を確認する**
```sql
select count(*) from ANALYTICS_PROD.MARTS.MART_TRANSACTIONS;
```
- 期待結果：エラーなく実行でき、件数が手順2-2で取り込んだ取引の件数（重複排除後の`RAW_PROD`の件数）と一致する

**4-2. カテゴリ別の月次支出を確認する**
```sql
select
    date_trunc('month', transaction_date) as month,
    category_major,
    sum(amount) as expense
from ANALYTICS_PROD.MARTS.MART_TRANSACTIONS
where transaction_type = 'expense'
group by 1, 2
order by 1, 2;
```
- 期待結果：月×大項目ごとの支出額が表示され、マネーフォワードMEのアプリ上の月ごと・カテゴリごとの支出額とおおむね一致する

以上でリリースは完了。

## 失敗した場合の対応
- 実施した手順の番号と、表示されたエラーメッセージをClaudeに共有する
- **共有する前に、エラーメッセージに取引の内容（店名・金額・メモ等）が含まれていないかを確認し、含まれている場合はその部分を伏せる**（Claudeは実データを読まないため。dbtのテスト失敗の表示は件数のみで、取引の内容は通常含まれない）
- Claudeは、PRODのデータを参照しての原因調査は行わない。データの中身の確認が必要な場合は、Claudeが確認用のSQLを用意し、ユーザーが実行して結果の要点（件数等）を共有する
- 手順3（dbt）で失敗した場合、`ANALYTICS_PROD`は`RAW_PROD`から作り直せるため、原因を修正した後に手順3からやり直せばよい
- 手順2（取り込み）で失敗した場合、取り込みスクリプトはアップロードしたファイルを`inbox`から削除するため、原因を修正した後に手順2-2からやり直せばよい

## 実施記録
| 実施日 | 実施者 | 結果 | 備考 |
|---|---|---|---|
| | | | |
