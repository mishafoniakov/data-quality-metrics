{{ config(materialized='view') }}

select
    'nodes' as entity_type,
    source,
    count(*) as cnt
from {{ source('lineage', 'nodes') }}
group by source

union all

select
    'edges' as entity_type,
    source,
    count(*) as cnt
from {{ source('lineage', 'edges') }}
group by source
