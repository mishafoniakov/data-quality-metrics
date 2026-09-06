{{ config(materialized='view') }}

select
    source,
    count(*) filter (where last_seen_at >= now() - interval '7 days') as edges_seen_7d,
    max(last_seen_at) as last_seen_at,
    case
        when count(*) filter (where last_seen_at >= now() - interval '2 days') = 0
            then 'lost_collection'
        else 'ok'
    end as collector_status
from {{ source('lineage', 'edges') }}
group by source
