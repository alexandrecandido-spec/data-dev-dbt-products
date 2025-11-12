{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['ticket_id'],
        on_schema_change = 'fail',
        tags = ['cx','daily-6am']
) }}    

WITH existing_data AS (
    {{ get_existing_data(this, ['ticket_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),
tickets_labels AS 
(
    SELECT 
        ticket_id,
        external_id,
        url,
        created_at,
        updated_at,
        due_at,
        status,
        type,
        priority,
        ticket_form_id,
        has_incidents,
        is_public,
        subject,
        raw_subject,
        description,
        tags,
        custom_fields,
        requester_id,
        recipient,
        organization_id,
        assignee_id,
        group_id,
        brand_id,
        submitter_id,
        parent_ticket_id,
        problem_id,
        followup_ids,
        collaborator_ids,
        follower_ids,
        email_cc_ids,
        forum_topic_id,
        sharing_agreement_ids,
        via_channel,
        allow_channelback,
        allow_attachments,
        satisfaction_score,
        satisfaction_reason,
        satisfaction_comment,
        sla,
        sla_min,
        main_topic,
        secondary_topic,
        subtopic,
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
        is_bot,
        is_automation,
        is_merged,
        is_spam,
        is_test,
        is_side_conversation
    FROM {{ ref("_int_cx__zendesk_tickets_label__ref") }}
)
SELECT 
  tickets_labels.*,
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