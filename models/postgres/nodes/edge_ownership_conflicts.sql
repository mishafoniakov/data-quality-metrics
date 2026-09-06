{{ config(materialized='view') }}

select
    src,
    dst,
    count(distinct source) as cnt
from {{ source('lineage', 'edges') }}
group by
    src,
    dst
having count(distinct source) > 1
