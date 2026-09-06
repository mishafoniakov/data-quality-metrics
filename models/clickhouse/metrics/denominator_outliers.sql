{{ config(materialized='view') }}

select
    a.channel,
    a.check_name,
    m.total_count,
    a.metric_value
from {{ source('dq', 'alerts') }} as a
left join {{ source('dq', 'metrics') }} as m
    on a.window_start = m.window_start
    and a.channel = m.channel
    and a.event_channel = m.event_channel
    and a.event_subtype = m.event_subtype
where a.window_start >= toStartOfDay(now()) - interval 30 day
    and m.total_count < 50
order by m.total_count asc
