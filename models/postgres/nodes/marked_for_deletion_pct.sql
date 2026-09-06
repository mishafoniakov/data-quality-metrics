{{ config(materialized='view') }}

select
    round(
        (count(*) filter (where coalesce(marked_for_deletion, 0) <> 0) * 100.0)
        / nullif(count(*), 0),
        2
    ) as marked_pct
from {{ source('lineage', 'edges') }}
