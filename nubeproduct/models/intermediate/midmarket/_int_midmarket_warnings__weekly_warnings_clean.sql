SELECT 
    CAST(audit_last_updated_at - interval '7' day AS DATE) as date_from,
    CAST(audit_last_updated_at AS DATE) as date_to,
    deal_id,
    store_id,
    warning_root_cause_1,
    warning_root_cause_2,
    warning_summary,
    warning_type,
    competitor_identified,
    CAST(date_entered_warning AS DATE) as date_entered_warning,
    CAST(date_exited_warning AS DATE) as date_exited_warning
FROM 
    {{ source('int_data_legacy', 'stitchdata__success_deals_warning') }} w