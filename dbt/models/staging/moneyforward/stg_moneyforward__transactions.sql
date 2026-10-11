with source as (

    select * from {{ source('moneyforward', 'transactions') }}

)

select
    id as transaction_id,
    transaction_date,
    description,
    amount,
    institution_name,
    category_major,
    category_minor,
    memo,
    is_target,
    is_transfer
from source
