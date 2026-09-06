{{ config(materialized='view') }}

select
    toHour(window_start) as hour_of_day,
    toMinute(window_start) as minute_of_hour,
    count(*) as alert_count
from {{ source('dq', 'alerts') }}
where window_start >= toStartOfDay(now()) - interval 30 day
group by
    toHour(window_start),
    toMinute(window_start)
order by alert_count desc
