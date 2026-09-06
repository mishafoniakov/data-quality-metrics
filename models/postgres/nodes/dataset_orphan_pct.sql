{{ config(materialized='view') }}

select
    round(
        (count(distinct id) filter (where edge_count = 0) * 100.0)
        / nullif(count(distinct id), 0),
        2
    ) as orphan_pct
from (
    select
        n.id as id,
        count(distinct e.id) filter (where e.id is not null) as edge_count
    from {{ source('lineage', 'nodes') }} as n
    left join {{ source('lineage', 'edges') }} as e
        on n.id = e.src
        or n.id = e.dst
    where n.node_type = 'dataset'
    group by n.id
) as q_1
