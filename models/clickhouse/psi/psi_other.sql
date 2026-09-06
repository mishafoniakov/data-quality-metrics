{{ config(materialized='view') }}

select
    channel,
    event_channel,
    subchannel,
    event_type,
    event_subtype,
    sum((actual_share - expected_share) * ln(actual_share / expected_share)) as psi
from {{ ref('psi_shares') }}
group by
    channel,
    event_channel,
    subchannel,
    event_type,
    event_subtype
order by psi desc
