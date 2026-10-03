# 実装タスク一覧

## タスク

- [x] 1. AWS側の構築
    - [x] S3バケット`practice-data-platform-raw`を作成する（`ap-northeast-1`、パブリックアクセス完全ブロック）
    - [x] フォルダ構成（`prod/moneyforward/transactions/{inbox,archive}`、`dev/moneyforward/transactions/{inbox,archive}`）を作成する
    - [x] ローカルのAWS CLI用に、S3の読み書き権限のみを持つ個人用IAMユーザーを作成する（構築中は一時的にS3FullAccess＋IAMFullAccessを付与し、完了後にこのバケットへの読み書きのみへ絞り込み済み）
- [x] 2. Snowflake側：ストレージインテグレーションを作成する（`RAW_PROD_S3_INTEGRATION`／`RAW_DEV_S3_INTEGRATION`）
    - [x] 発行された`STORAGE_AWS_IAM_USER_ARN`・`STORAGE_AWS_EXTERNAL_ID`を確認する
- [x] 3. AWS側：IAMロール・ポリシーを作成する（`snowflake-raw-prod-role`／`snowflake-raw-dev-role`とそれぞれのポリシー）
    - [x] 信頼ポリシーに、タスク2で確認したSnowflake側の情報を設定する
- [x] 4. Snowflake側：外部ステージ・ファイルフォーマットを作成する
    - [x] `MONEYFORWARD_CSV_FORMAT`（CSV・`ENCODING='SHIFTJIS'`・`SKIP_HEADER=1`・`DATE_FORMAT='YYYY/MM/DD'`）
    - [x] `RAW_PROD.MONEYFORWARD.S3_STAGE`／`RAW_DEV.MONEYFORWARD.S3_STAGE`
    - [x] ステージの`USAGE`権限を、それぞれ`LOADER_PROD`／`LOADER_DEV`にのみ付与する
- [x] 5. Snowflake側：テーブルを作成する
    - [x] `TRANSACTIONS_STG`（一時テーブル）
    - [x] `TRANSACTIONS`（本体テーブル）
    - [x] `RAW_PROD`・`RAW_DEV`の両方に作成する
- [x] 6. 取り込みSQL（`COPY INTO`＋`MERGE`）を`ingestion/`配下に作成する（PROD用・DEV用）
- [x] 7. アップロード・取り込みスクリプトを`ingestion/`配下に作成する（PowerShell。アップロード時にファイル名をASCIIの日時ベース名に変換）
    - [x] `aws s3 cp`でアップロード
    - [x] Snowflake CLIで取り込みSQLを実行
    - [x] 成功したら`aws s3 mv`で`inbox`から`archive`へ移動
- [x] 8. `sample_data/`のダミーCSVを使い、DEV環境で動作確認する
    - [x] 初回実行で正しく`RAW_DEV.MONEYFORWARD.TRANSACTIONS`に取り込まれることを確認する（日本語の値・真偽値・日付も正しく変換されることを確認）
    - [x] 同じファイルで再実行しても重複しないことを確認する（`MERGE`で挿入0件を確認。STGテーブルへの再読み込み自体は`CREATE OR REPLACE`のため毎回発生するが、本体テーブルへの重複は発生しないことを確認）
- [x] 9. 永続ドキュメントを更新する
    - [x] `docs/interfaces.md`の「格納先」欄を、確定したS3パスに更新する
    - [x] `docs/interfaces.md`の「稼働状況」を更新する（検討中→稼働中。`docs/connections.md`は稼働状況の列を持たない設計のため対象外）
- [ ] 10. コミット・feature pushし、PRを作成してCIレビューを通し、mainへマージする

## 実装中に判明した事項（design.mdにも反映済み）
- `ENCODING = 'SJIS'`は無効。正しくは`'SHIFTJIS'`
- 日付`1900/01/01`（`YYYY/MM/DD`形式）はデフォルトで認識されず、`DATE_FORMAT`の明示指定が必要だった
- 日本語ファイル名のままS3へアップロードすると、キー名が文字化けすることが判明。アップロード時にASCIIの日時ベース名へ変換するルールに変更した
- PowerShellスクリプトは、日本語コメントを含めるとBOM無しファイルで構文エラーになったため、英語（ASCII）で記述した
- 詳細は、メモリ（`project_ingestion_pipeline_gotchas.md`）にも記録済み
