{{ config(materialized='view') }}

select
    channel,
    check_name,
    window_start,
    window_end,
    dateDiff('minute', window_start, window_end) as latency_minutes
from {{ source('dq', 'alerts') }}
where window_start >= toStartOfDay(now()) - interval 30 day
    and window_end is not null
    and dateDiff('minute', window_start, window_end) > 15
order by latency_minutes desc
