{{ config(materialized='view') }}

with
alerts as (
    select
        window_start,
        (toDayOfWeek(window_start) - 1) * 24 + toHour(window_start) as hour_of_week,
        channel::String as channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        check_name
    from {{ source('dq', 'alerts') }}
),
baseline as (
    select
        channel::String as channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        hour_of_week,
        n_samples,
        total_count,
        computed_at
    from {{ source('dq', 'baseline_seasonal') }}
)
select
    a.channel,
    a.event_channel,
    a.subchannel,
    a.event_type,
    a.event_subtype,
    count(*) as alerts_with_weak_baseline,
    round(avg(b.n_samples), 1) as avg_n_samples,
    round(avg(b.total_count), 1) as avg_total_count
from alerts as a
left join baseline as b
    on a.hour_of_week = b.hour_of_week
    and a.channel = b.channel
    and a.event_channel = b.event_channel
    and a.subchannel = b.subchannel
    and a.event_type = b.event_type
    and a.event_subtype = b.event_subtype
where a.window_start >= toStartOfDay(now()) - interval 30 day
    and (b.n_samples < 30 or b.total_count < 1000)
group by
    a.channel,
    a.event_channel,
    a.subchannel,
    a.event_type,
    a.event_subtype
