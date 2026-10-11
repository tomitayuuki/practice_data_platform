-- martsにstagingの全行が含まれていることを検証する（件数が一致しなければ1行返し、失敗とする）
with counts as (

    select
        (select count(*) from {{ ref('stg_moneyforward__transactions') }}) as staging_count,
        (select count(*) from {{ ref('mart_transactions') }}) as mart_count

)

select *
from counts
where staging_count <> mart_count
