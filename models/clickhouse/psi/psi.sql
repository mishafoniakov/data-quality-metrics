{{ config(materialized='view') }}

with
metrics as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        total_count,
        window_start,
        category,
        count_value
    from {{ source('dq', 'metrics') }}
    array join
        mapKeys(category_counts) as category,
        mapValues(category_counts) as count_value
    where window_start = (select max(window_start) from {{ source('dq', 'metrics') }})
),
baseline as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        hour_of_week,
        total_count,
        computed_at,
        category,
        count_value
    from {{ source('dq', 'baseline_seasonal') }}
    array join
        mapKeys(category_counts) as category,
        mapValues(category_counts) as count_value
    where hour_of_week = (toDayOfWeek(now()) - 1) * 24 + toHour(now())
)
select
    channel,
    event_channel,
    subchannel,
    event_type,
    event_subtype,
    sum((actual_share - expected_share) * ln(actual_share / expected_share)) as psi
from (
    select distinct
        coalesce(m.channel, b.channel) as channel,
        coalesce(m.event_channel, b.event_channel) as event_channel,
        coalesce(m.subchannel, b.subchannel) as subchannel,
        coalesce(m.event_type, b.event_type) as event_type,
        coalesce(m.event_subtype, b.event_subtype) as event_subtype,
        coalesce(m.category, b.category) as category,
        coalesce(m.count_value, 0) / coalesce(m.total_count, 1) as actual_share,
        coalesce(b.count_value, 0) / coalesce(b.total_count, 1) as expected_share
    from metrics as m
    full outer join baseline as b
        on m.channel = b.channel
        and m.event_channel = b.event_channel
        and m.subchannel = b.subchannel
        and m.event_type = b.event_type
        and m.event_subtype = b.event_subtype
        and m.category = b.category
) as q_1
where not (actual_share = 0 and expected_share = 0)
group by
    channel,
    event_channel,
    subchannel,
    event_type,
    event_subtype
order by psi desc
