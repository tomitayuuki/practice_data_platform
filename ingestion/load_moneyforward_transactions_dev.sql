-- マネーフォワード取引明細：RAW_DEVへの取り込み（COPY INTO → MERGE）
-- .steering/20261003-ingestion-pipeline/design.md に対応

USE ROLE LOADER_DEV;

CREATE OR REPLACE TABLE RAW_DEV.MONEYFORWARD.TRANSACTIONS_STG (
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

COPY INTO RAW_DEV.MONEYFORWARD.TRANSACTIONS_STG
    (is_target, transaction_date, description, amount, institution_name,
     category_major, category_minor, memo, is_transfer, id)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
    FROM @RAW_DEV.MONEYFORWARD.S3_STAGE
)
FILE_FORMAT = (FORMAT_NAME = 'RAW_DEV.MONEYFORWARD.MONEYFORWARD_CSV_FORMAT');

-- STG側に同一idが複数行存在する場合（inboxに未処理ファイルが複数残っていた場合等）に
-- 二重にINSERTされることを防ぐため、idで一意にしてからMERGEする。
MERGE INTO RAW_DEV.MONEYFORWARD.TRANSACTIONS AS target
USING (
    SELECT *
    FROM RAW_DEV.MONEYFORWARD.TRANSACTIONS_STG
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY transaction_date DESC) = 1
) AS source
ON target.id = source.id
WHEN NOT MATCHED THEN INSERT (is_target, transaction_date, description, amount,
    institution_name, category_major, category_minor, memo, is_transfer, id)
    VALUES (source.is_target, source.transaction_date, source.description, source.amount,
    source.institution_name, source.category_major, source.category_minor,
    source.memo, source.is_transfer, source.id);

SELECT COUNT(*) AS loaded_row_count FROM RAW_DEV.MONEYFORWARD.TRANSACTIONS_STG;
