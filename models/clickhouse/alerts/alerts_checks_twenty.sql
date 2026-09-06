{{ config(materialized='view') }}

with
group_alerts as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        check_name,
        count(*) as alert_count,
        count(distinct window_start) as distinct_windows,
        count(distinct toDate(window_start)) as active_days,
        count(*) filter (where severity = 'critical') as critical_count,
        count(*) filter (where severity = 'warning') as warning_count
    from {{ source('dq', 'alerts') }}
    where window_start >= toStartOfDay(now()) - interval 30 day
    group by
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        check_name
)
select
    channel,
    event_channel,
    subchannel,
    event_type,
    event_subtype,
    check_name,
    alert_count,
    distinct_windows,
    critical_count,
    warning_count,
    round(
        (alert_count * 1.0 / greatest(active_days, 1))
        + (active_days * 1.0 / 30) * 100
        + (critical_count * 3.0)
        + (warning_count * 1.0)
        + (alert_count * 1.0 / greatest(distinct_windows, 1)),
        2
    ) as noise_score
from group_alerts
order by noise_score desc
limit 20
