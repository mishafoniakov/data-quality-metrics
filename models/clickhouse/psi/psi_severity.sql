{{ config(materialized='view') }}

{% set warn = 0.10 %}
{% set critical = 0.25 %}

select
    channel,
    event_channel,
    subchannel,
    event_type,
    event_subtype,
    psi,
    multiIf(
        psi >= {{ critical }}, 'critical',
        psi >= {{ warn }}, 'warning',
        'info'
    ) as severity
from {{ ref('psi_other') }}
