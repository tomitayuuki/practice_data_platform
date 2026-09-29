# 基本設計書（作業単位）

## 概要
`requirements.md`のスコープに従い、Snowflake上に作成する具体的なオブジェクト名と、構築の手順（依存関係の順序）を定義する。

## 作成するオブジェクト一覧

| 種別 | 名前 | 備考 |
|---|---|---|
| データベース | `RAW_PROD`／`RAW_DEV`／`ANALYTICS_PROD`／`ANALYTICS_DEV` | `docs/architecture.md`で確定済み |
| スキーマ | `RAW_PROD.moneyforward`／`RAW_DEV.moneyforward`、`ANALYTICS_PROD.staging`／`.intermediate`／`.marts`、`ANALYTICS_DEV.staging`／`.intermediate`／`.marts` | レイヤー・システムごとの分割は`docs/development-standards.md`1.8に準拠 |
| ロール | `LOADER_DEV`／`LOADER_PROD`／`TRANSFORMER_DEV`／`TRANSFORMER_PROD`／`REPORTER_DEV`／`REPORTER_PROD` | `docs/architecture.md`で確定済み |
| ウェアハウス | `MAIN_WH` | 新規に命名。用途別に分割しない共有ウェアハウス |
| リソースモニター | `MONTHLY_BUDGET_MONITOR` | 新規に命名。`MAIN_WH`に紐づける |

ユーザーは新規作成せず、既存の個人ユーザーに上記6ロールを付与する（`docs/architecture.md`の方針通り、ユーザーは1つのみ）。

## 構築手順（依存関係の順序）
1. ウェアハウス（`MAIN_WH`）を作成する（X-Small・シングルクラスタ・自動停止60秒）
2. リソースモニター（`MONTHLY_BUDGET_MONITOR`）を作成し、`MAIN_WH`に紐づける
3. データベース4つを作成する
4. 各データベース内にスキーマを作成する
5. ロール6つを作成する
6. 各ロールに、対応するデータベース・スキーマへの権限（参照・書き込み等）と、`MAIN_WH`への`USAGE`権限を付与する（権限範囲は`docs/architecture.md`のロール・権限設計表の通り）
7. 個人ユーザーに6ロールを付与する
8. 個人ユーザーの多要素認証（MFA）を有効化する

## 前提条件
- Snowflakeアカウントが作成済みであること
    - クラウド：AWS、リージョン：ap-northeast-1（東京）、エディション：Standardで作成する（`docs/architecture.md`参照）。これはSnowflakeの動作環境の選択であり、本作業単位でAWSアカウント自体を必要とするわけではない
    - 未作成の場合は、本作業単位の着手前にユーザー側で用意する
    - なお、AWSアカウント自体は次の作業単位「取り込みパイプライン構築」（S3連携）以降で必要になる

## 未確定事項
- リソースモニターの具体的なクレジット上限値（25%／50%／75%／100%に相当する数値）は、契約プランのクレジット単価が判明した時点で確定する。それまでは暫定値を設定し、判明次第調整する
