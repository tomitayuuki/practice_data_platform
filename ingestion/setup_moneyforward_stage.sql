-- マネーフォワード取り込み用：外部ステージ・ファイルフォーマット・テーブルの構築
-- .steering/20261003-ingestion-pipeline/design.md に対応
-- ストレージインテグレーション（RAW_PROD_S3_INTEGRATION／RAW_DEV_S3_INTEGRATION）は
-- 作成済みであることが前提（AWS側のIAMロールとの信頼関係も設定済み）。

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- PROD
-- ============================================================
CREATE OR REPLACE FILE FORMAT RAW_PROD.MONEYFORWARD.MONEYFORWARD_CSV_FORMAT
    TYPE = 'CSV'
    ENCODING = 'SHIFTJIS'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    DATE_FORMAT = 'YYYY/MM/DD';

CREATE STAGE IF NOT EXISTS RAW_PROD.MONEYFORWARD.S3_STAGE
    URL = 's3://practice-data-platform-raw/prod/moneyforward/transactions/inbox/'
    STORAGE_INTEGRATION = RAW_PROD_S3_INTEGRATION
    FILE_FORMAT = RAW_PROD.MONEYFORWARD.MONEYFORWARD_CSV_FORMAT;

CREATE TABLE IF NOT EXISTS RAW_PROD.MONEYFORWARD.TRANSACTIONS (
    is_target BOOLEAN,
    transaction_date DATE,
    description STRING,
    amount NUMBER,
    institution_name STRING,
    category_major STRING,
    category_minor STRING,
    memo STRING,
    is_transfer BOOLEAN,
    id STRING
);

GRANT USAGE ON INTEGRATION RAW_PROD_S3_INTEGRATION TO ROLE LOADER_PROD;
GRANT USAGE ON STAGE RAW_PROD.MONEYFORWARD.S3_STAGE TO ROLE LOADER_PROD;
GRANT USAGE ON FILE FORMAT RAW_PROD.MONEYFORWARD.MONEYFORWARD_CSV_FORMAT TO ROLE LOADER_PROD;

-- ============================================================
-- DEV
-- ============================================================
CREATE OR REPLACE FILE FORMAT RAW_DEV.MONEYFORWARD.MONEYFORWARD_CSV_FORMAT
    TYPE = 'CSV'
    ENCODING = 'SHIFTJIS'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    DATE_FORMAT = 'YYYY/MM/DD';

CREATE STAGE IF NOT EXISTS RAW_DEV.MONEYFORWARD.S3_STAGE
    URL = 's3://practice-data-platform-raw/dev/moneyforward/transactions/inbox/'
    STORAGE_INTEGRATION = RAW_DEV_S3_INTEGRATION
    FILE_FORMAT = RAW_DEV.MONEYFORWARD.MONEYFORWARD_CSV_FORMAT;

CREATE TABLE IF NOT EXISTS RAW_DEV.MONEYFORWARD.TRANSACTIONS (
    is_target BOOLEAN,
    transaction_date DATE,
    description STRING,
    amount NUMBER,
    institution_name STRING,
    category_major STRING,
    category_minor STRING,
    memo STRING,
    is_transfer BOOLEAN,
    id STRING
);

GRANT USAGE ON INTEGRATION RAW_DEV_S3_INTEGRATION TO ROLE LOADER_DEV;
GRANT USAGE ON STAGE RAW_DEV.MONEYFORWARD.S3_STAGE TO ROLE LOADER_DEV;
GRANT USAGE ON FILE FORMAT RAW_DEV.MONEYFORWARD.MONEYFORWARD_CSV_FORMAT TO ROLE LOADER_DEV;
