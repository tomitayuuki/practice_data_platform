# 要件定義書（作業単位）

## 目的
`docs/architecture.md`で定義したSnowflake上のインフラ（データベース・スキーマ・ロール・ウェアハウス・リソースモニター）を実際に構築する。データの取り込み・変換処理は対象外とし、その土台となるアカウント構成のみを対象とする。

## スコープ

### 対象
- データベース：`RAW_PROD`／`RAW_DEV`／`ANALYTICS_PROD`／`ANALYTICS_DEV`の作成
- 各データベース内のスキーマ作成
    - `RAW_PROD`／`RAW_DEV`：`moneyforward`スキーマ
    - `ANALYTICS_PROD`／`ANALYTICS_DEV`：`staging`／`intermediate`／`marts`スキーマ
- ロール作成：`LOADER_DEV`／`LOADER_PROD`／`TRANSFORMER_DEV`／`TRANSFORMER_PROD`／`REPORTER_DEV`／`REPORTER_PROD`の6ロールと、それぞれの権限付与（`docs/architecture.md`のロール・権限設計に準拠）
- 個人ユーザーへの6ロール付与
- 個人ユーザーへの多要素認証（MFA）の有効化
- ウェアハウス作成：X-Small・シングルクラスタ・自動停止60秒
- リソースモニター作成：25%／50%／75%通知、100%到達時にウェアハウス自動停止

### 対象外
- S3ストレージ統合、外部ステージ、`COPY INTO`／`MERGE`ロジック（次の作業単位「取り込みパイプライン構築」で対応）
- dbtプロジェクトの作成、モデル実装（その次の作業単位「dbtモデリング」で対応）

## 要件
- `docs/architecture.md`の「Snowflakeデータベース・スキーマ構成」「ロール・権限設計」「コンピュートリソース」の内容と、実際に作成されるオブジェクトが一致していること
- 各ロールが、想定した環境（DEV／PROD）の範囲を超えて参照・書き込みできないこと（環境を跨いだ権限を持たないこと）

## 受け入れ基準
- 上記「対象」に挙げた全てのオブジェクトが、Snowflake上に作成されていること
- 各ロールの権限が設計通りであることを確認できること（例：`TRANSFORMER_DEV`で`ANALYTICS_PROD`に書き込めないことを確認する等）
