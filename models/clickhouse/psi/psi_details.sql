{{ config(materialized='view') }}

with
contrib as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        category,
        window_start,
        baseline_version,
        actual_total,
        expected_total,
        actual_count,
        expected_count,
        actual_share,
        expected_share,
        if(actual_share >= expected_share, 'up', 'down') as direction,
        (actual_share - expected_share) * ln(actual_share / expected_share) as psi_contribution
    from {{ ref('psi_shares') }}
),
packed as (
    select
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype,
        any(window_start) as window_start,
        any(baseline_version) as baseline_version,
        any(actual_total) as total_count_current,
        any(expected_total) as total_count_baseline,
        sum(psi_contribution) as sum_psi_contributions,
        groupArrayIf(category, actual_count > 0 and expected_count = 0) as new_categories,
        groupArrayIf(category, actual_count = 0 and expected_count > 0) as disappeared_categories,
        arraySlice(
            arrayReverseSort(
                x -> x.5,
                groupArray((
                    category,
                    actual_share,
                    expected_share,
                    direction,
                    psi_contribution
                ))
            ),
            1,
            3
        ) as top_contributors
    from contrib
    group by
        channel,
        event_channel,
        subchannel,
        event_type,
        event_subtype
)
select
    p.channel,
    p.event_channel,
    p.subchannel,
    p.event_type,
    p.event_subtype,
    s.psi,
    s.severity,
    concat(
        '{"psi":', toString(round(s.psi, 4)),
        ',"severity":"', s.severity, '"',
        ',"top_contributors":[',
        arrayStringConcat(
            arrayMap(
                x -> concat(
                    '{"category":"', replaceAll(toString(x.1), '"', '\\"'), '"',
                    ',"baseline_share":', toString(round(x.3, 4)),
                    ',"actual_share":', toString(round(x.2, 4)),
                    ',"direction":"', toString(x.4), '"',
                    ',"psi_contribution":', toString(round(x.5, 4)),
                    '}'
                ),
                p.top_contributors
            ),
            ','
        ),
        '],"new_categories":[',
        arrayStringConcat(
            arrayMap(x -> concat('"', replaceAll(x, '"', '\\"'), '"'), p.new_categories),
            ','
        ),
        '],"disappeared_categories":[',
        arrayStringConcat(
            arrayMap(x -> concat('"', replaceAll(x, '"', '\\"'), '"'), p.disappeared_categories),
            ','
        ),
        '],"total_count_current":', toString(p.total_count_current),
        ',"total_count_baseline":', toString(p.total_count_baseline),
        ',"baseline_version":"', toString(p.baseline_version), '"',
        ',"window_start":"', toString(p.window_start), '"',
        ',"contributions_sum_check":{',
        '"sum_psi_contributions":', toString(round(p.sum_psi_contributions, 4)),
        ',"equals_total_psi":', if(abs(p.sum_psi_contributions - s.psi) < 0.0001, 'true', 'false'),
        '}}'
    ) as details
from packed as p
inner join {{ ref('psi_severity') }} as s
    on p.channel = s.channel
    and p.event_channel = s.event_channel
    and p.subchannel = s.subchannel
    and p.event_type = s.event_type
    and p.event_subtype = s.event_subtype
