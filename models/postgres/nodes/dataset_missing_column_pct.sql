{{ config(materialized='view') }}

with
dataset_table as (
    select distinct n.id
    from {{ source('lineage', 'nodes') }} as n
    inner join {{ source('lineage', 'edges') }} as e
        on n.id = e.src
        or n.id = e.dst
    where n.node_type = 'dataset'
),
dataset_column as (
    select distinct dataset_id
    from {{ source('lineage', 'columns') }}
)
select
    round(
        (count(*) filter (where dc.dataset_id is null) * 100.0)
        / nullif(count(*), 0),
        2
    ) as missing_column
from dataset_table as dt
left join dataset_column as dc
    on dt.id = dc.dataset_id
