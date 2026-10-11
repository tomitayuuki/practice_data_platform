with transactions as (

    select * from {{ ref('stg_moneyforward__transactions') }}

),

classified as (

    select
        *,
        -- 計算対象外の判定を最優先とし、次に大項目が「収入」かどうかで判定する
        case
            when not is_target then 'excluded'
            when category_major = '収入' then 'income'
            else 'expense'
        end as transaction_type
    from transactions

)

select
    transaction_id,
    transaction_date,
    transaction_type,
    -- グラフ用の金額：収入・支出とも正の値に揃える（返金は支出の負の値になる）。対象外はNULL
    case transaction_type
        when 'income' then amount
        when 'expense' then -amount
    end as amount,
    amount as signed_amount,
    description,
    institution_name,
    category_major,
    category_minor,
    memo,
    is_target,
    is_transfer
from classified
