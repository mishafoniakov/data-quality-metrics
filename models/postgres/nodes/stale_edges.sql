{{ config(materialized='view') }}

with live_collectors as (
    select source
    from {{ source('lineage', 'edges') }}
    group by source
    having max(last_seen_at) >= now() - interval '2 days'
)
select
    e.src,
    e.dst,
    e.source,
    e.last_seen_at
from {{ source('lineage', 'edges') }} as e
inner join live_collectors as c
    on e.source = c.source
where e.last_seen_at < now() - interval '30 days'
    and coalesce(e.marked_for_deletion, 0) = 0
