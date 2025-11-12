{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['macro_id'],
        on_schema_change = 'fail',
        tags = ['cx','daily-6am']
) }}    

WITH existing_data AS (
    {{ get_existing_data(this, ['macro_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
tickets_labels AS 
(
    SELECT 
        ticket_id,
        requester_id,
        external_id,
        created_at,
        updated_at,
        status,
        ticket_form_id,
        subject,
        description,
        url,
        raw_subject,
        custom_fields,
        tags,
        allow_attachments,
        allow_channelback,
        assignee_id,
        brand_id,
        collaborator_ids,
        due_at,
        email_cc_ids,
        follower_ids,
        followup_ids,
        forum_topic_id,
        group_id,
        has_incidents,
        is_public,
        organization_id,
        priority,
        problem_id,
        recipient,
        satisfaction_rating_score,
        satisfaction_rating,
        sharing_agreement_ids,
        submitter_id,
        type,
        is_partner,
        store_status,
        store_status_by_order,
        store_tier_np_pn,
        store_plan,
        client_segment,
        client_profile,
        team_guru,
        squad_guru,
        bu_guru,
        sla,
        sla_min,
        main_topic,
        secondary_topic,
        subtopic,
        is_bot,
        is_automation,
        is_merged,
        is_spam,
        is_test,
        is_side_conversation,
        parent_ticket_id
    FROM {{ ref("_int_cx__zendesk_tickets_labels__ref") }}
)
SELECT 
  *,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM tickets_labels
LEFT JOIN existing_data AS e
    ON tickets_labels.ticket_id = e.ticket_id
    {% if is_incremental() %}
WHERE    
      tickets_labels.updated_at > 
        (
            SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}