{{ config(materialized='view') }}

{% set top_k = 3 %}
{% set alpha = 0.5 %}
{% set n_buckets = top_k + 1 %}
{% set min_volume = 100 %}
{% set min_samples = 30 %}

with
metrics_raw as (
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
baseline_raw as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        total_count,
        n_samples,
        computed_at,
        category,
        count_value,
        row_number() over (
            partition by channel, event_channel, subchannel, event_type, event_subtype
            order by count_value desc
        ) as rn
    from {{ source('dq', 'baseline_seasonal') }}
    array join
        mapKeys(category_counts) as category,
        mapValues(category_counts) as count_value
    where hour_of_week = (toDayOfWeek(now()) - 1) * 24 + toHour(now())
),
baseline_top as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        category,
        1 as is_top
    from baseline_raw
    where rn <= {{ top_k }}
),
baseline as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        any(total_count) as total_count,
        any(n_samples) as n_samples,
        any(computed_at) as computed_at,
        category,
        sum(count_value) as count_value
    from (
        select
            channel,
            event_channel,
            subchannel,
            event_type,
            event_subtype,
            total_count,
            n_samples,
            computed_at,
            if(rn <= {{ top_k }}, category, '__other__') as category,
            count_value
        from baseline_raw
    )
    group by
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        category
),
metrics as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        any(total_count) as total_count,
        any(window_start) as window_start,
        category,
        sum(count_value) as count_value
    from (
        select
            m.channel,
            m.event_channel,
            m.subchannel,
            m.event_type,
            m.event_subtype,
            m.total_count,
            m.window_start,
            if(t.is_top = 1, m.category, '__other__') as category,
            m.count_value
        from metrics_raw as m
        left join baseline_top as t
            on m.channel = t.channel
            and m.event_channel = t.event_channel
            and m.subchannel = t.subchannel
            and m.event_type = t.event_type
            and m.event_subtype = t.event_subtype
            and m.category = t.category
    )
    group by
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        category
)
select
    coalesce(m.channel, b.channel) as channel,
    coalesce(m.event_channel, b.event_channel) as event_channel,
    coalesce(m.subchannel, b.subchannel) as subchannel,
    coalesce(m.event_type, b.event_type) as event_type,
    coalesce(m.event_subtype, b.event_subtype) as event_subtype,
    coalesce(m.category, b.category) as category,
    coalesce(m.window_start, toDateTime(0)) as window_start,
    coalesce(b.computed_at, toDateTime(0)) as baseline_version,
    coalesce(m.total_count, 0) as actual_total,
    coalesce(b.total_count, 0) as expected_total,
    coalesce(b.n_samples, 0) as n_samples,
    coalesce(m.count_value, 0) as actual_count,
    coalesce(b.count_value, 0) as expected_count,
    (coalesce(m.count_value, 0) + {{ alpha }})
        / (coalesce(m.total_count, 0) + {{ alpha }} * {{ n_buckets }}) as actual_share,
    (coalesce(b.count_value, 0) + {{ alpha }})
        / (coalesce(b.total_count, 0) + {{ alpha }} * {{ n_buckets }}) as expected_share
from metrics as m
full outer join baseline as b
    on m.channel = b.channel
    and m.event_channel = b.event_channel
    and m.subchannel = b.subchannel
    and m.event_type = b.event_type
    and m.event_subtype = b.event_subtype
    and m.category = b.category
where coalesce(m.total_count, 0) >= {{ min_volume }}
    and coalesce(b.total_count, 0) >= {{ min_volume }}
    and coalesce(b.n_samples, 0) >= {{ min_samples }}
