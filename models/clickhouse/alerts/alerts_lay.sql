{{ config(materialized='view') }}

with
alerts as (
    select
        window_start,
        channel::String as channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        check_name
    from {{ source('dq', 'alerts') }}
    where window_start >= toStartOfDay(now()) - interval 30 day
),
label as (
    select
        window_start,
        channel::String as channel,
        label
    from {{ source('dq', 'alert_labels') }}
    where window_start >= toStartOfDay(now()) - interval 30 day
)
select
    a.check_name,
    count(*) as total_alerts,
    count(*) filter (where l.label != 'unclear') as labeled_alerts,
    round(
        count(*) filter (where l.label in ('false_positive', 'known_issue'))
        / nullif(count(*) filter (where l.label in ('true_positive', 'false_positive', 'known_issue')), 0)
        * 100,
        2
    ) as noised_label
from alerts as a
left join label as l
    on a.window_start = l.window_start
    and a.channel = l.channel
group by a.check_name
