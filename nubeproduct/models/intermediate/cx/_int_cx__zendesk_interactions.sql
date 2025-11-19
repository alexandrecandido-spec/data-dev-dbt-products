WITH

 comments AS
(
  SELECT ticket_id, id, author_id, created_at, type, public
  FROM
  (
  SELECT *, row_number() over (PARTITION BY ticket_id, id ORDER BY coalesce(created_at,date('1900-01-01')) DESC) AS rnk
  FROM
  (
  SELECT ticket_id, id, author_id, created_at, type, public
  FROM   {{ source('int_zendesk_support_prod', 'ticket_comments') }}
  {% if is_incremental() %}
    WHERE  date(_airbyte_extracted_at) >= (select coalesce(max(date(sys_audit_updated_on)), date('1900-01-01')) from {{ this }})
  {% else %}
    UNION ALL
    SELECT ticket_id, id, author_id, created_at, type, public 
    FROM {{ source('int_zendesk_support_prod', 'legacy_comments') }}
  {% endif %}
  )
  ) WHERE rnk = 1
)

,comment_events AS 
(
  SELECT
   tc.ticket_id
  ,tc.id AS interaction_id
  ,tc.author_id
  ,lower(coalesce(ud.role, 'end-user')) AS author_type
  ,tc.created_at AS interaction_timestamp
  ,tc.type AS source
  ,CASE WHEN lower(coalesce(ud.role, 'end-user')) = 'end-user'  THEN TRUE ELSE FALSE END AS is_in_interaction
  ,CASE WHEN lower(coalesce(ud.role, 'end-user')) <> 'end-user' THEN TRUE ELSE FALSE END AS is_out_interaction
  FROM  comments tc
  LEFT JOIN {{ ref('s__general__zendesk_users__ref') }} ud ON ud.user_id = tc.author_id
  WHERE COALESCE(tc.author_id, -1) > 0
  AND   tc.public = TRUE
)

,ranked AS 
(
  SELECT
   ce.*
  ,ROW_NUMBER()               OVER (PARTITION BY ce.ticket_id ORDER BY ce.interaction_timestamp, ce.interaction_id) AS ticket_interaction_rank
  ,LAG(ce.is_in_interaction)  OVER (PARTITION BY ce.ticket_id ORDER BY ce.interaction_timestamp, ce.interaction_id) AS prev_is_in
  ,LAG(ce.is_out_interaction) OVER (PARTITION BY ce.ticket_id ORDER BY ce.interaction_timestamp, ce.interaction_id) AS prev_is_out
  ,LAG(ce.author_type)        OVER (PARTITION BY ce.ticket_id ORDER BY ce.interaction_timestamp, ce.interaction_id) AS prev_author_type
  ,LEAD(ce.author_type)       OVER (PARTITION BY ce.ticket_id ORDER BY ce.interaction_timestamp, ce.interaction_id) AS next_author_type
  FROM comment_events ce
)

,groups AS 
(
  SELECT
   r.*
  ,CASE WHEN r.prev_author_type IS NULL OR r.prev_author_type <> r.author_type THEN TRUE ELSE FALSE END AS is_start_interaction_group
  ,CASE WHEN r.next_author_type IS NULL OR r.next_author_type <> r.author_type THEN TRUE ELSE FALSE END AS is_end_interaction_group
  ,SUM(CASE WHEN r.prev_author_type IS NULL OR r.prev_author_type <> r.author_type THEN 1 ELSE 0 END) OVER (PARTITION BY r.ticket_id ORDER BY r.interaction_timestamp, r.interaction_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS interaction_group_id
  FROM ranked r
)

,blocks AS 
(
  SELECT
   g.*
  ,CASE WHEN g.is_in_interaction = TRUE AND (g.prev_is_in IS NULL OR g.prev_is_in = FALSE) THEN TRUE ELSE FALSE END AS is_start_in_interaction
  FROM groups g
)

,prev_io AS 
(
  SELECT
   b.*
  ,last_value(CASE WHEN b.is_in_interaction  THEN b.interaction_id        END, TRUE) OVER (PARTITION BY b.ticket_id ORDER BY b.interaction_timestamp, b.interaction_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS previous_in_interaction_id
  ,last_value(CASE WHEN b.is_out_interaction THEN b.interaction_id        END, TRUE) OVER (PARTITION BY b.ticket_id ORDER BY b.interaction_timestamp, b.interaction_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS previous_out_interaction_id
  ,last_value(CASE WHEN b.is_in_interaction  THEN b.interaction_timestamp END, TRUE) OVER (PARTITION BY b.ticket_id ORDER BY b.interaction_timestamp, b.interaction_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS previous_in_interaction_ts
  ,last_value(CASE WHEN b.is_out_interaction THEN b.interaction_timestamp END, TRUE) OVER (PARTITION BY b.ticket_id ORDER BY b.interaction_timestamp, b.interaction_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS previous_out_interaction_ts
  FROM blocks b
)

,assignee_id AS
(
  SELECT ticket_id, assignee_id, effective_from, COALESCE(LEAD(effective_from) OVER (PARTITION BY ticket_id ORDER BY effective_from, event_id),CAST('2100-12-31' AS TIMESTAMP)) AS effective_to
  FROM
  (
   SELECT ticket_id, event_id ,event_timestamp AS effective_from, cast(field_value as bigint) as assignee_id, ROW_NUMBER() OVER (PARTITION BY ticket_id, event_timestamp ORDER BY event_id DESC) AS rnk
   FROM   {{ ref('s__general__zendesk_tickets_events__event') }}
   WHERE  field_name = 'assignee_id'
   AND    coalesce(cast(field_value as bigint),-1) > 0
  ) WHERE rnk = 1
)

,group_id AS
(
  SELECT ticket_id, group_id, effective_from, COALESCE(LEAD(effective_from) OVER (PARTITION BY ticket_id ORDER BY effective_from, event_id),CAST('2100-12-31' AS TIMESTAMP)) AS effective_to
  FROM
  (
   SELECT ticket_id, event_id ,event_timestamp AS effective_from, cast(field_value as bigint) as group_id, ROW_NUMBER() OVER (PARTITION BY ticket_id, event_timestamp ORDER BY event_id DESC) AS rnk
   FROM   {{ ref('s__general__zendesk_tickets_events__event') }}
   WHERE  field_name = 'group_id'
   AND    coalesce(cast(field_value as bigint),-1) > 0
  ) WHERE rnk = 1
)

SELECT
 CAST(a.ticket_id AS BIGINT)                      AS ticket_id
,CAST(a.interaction_id AS BIGINT)                 AS interaction_id
,CAST(a.interaction_timestamp AS TIMESTAMP)       AS interaction_timestamp
,CAST(a.author_id AS BIGINT)                      AS author_id
,CAST(a.author_type AS STRING)                    AS author_type
,CAST(CASE WHEN a.author_type = 'end-user' THEN 'in' ELSE 'out' END AS STRING) AS interaction_type
,CAST(a.source AS STRING)                         AS source
,CAST(CASE WHEN a.author_id IN (17725524850324, 21842777841044) THEN TRUE ELSE FALSE END AS BOOLEAN) AS is_bot_interaction
,CAST(a.ticket_interaction_rank AS BIGINT)        AS ticket_interaction_rank
,CAST(a.interaction_group_id AS BIGINT)           AS interaction_group_id
,CAST(a.is_start_interaction_group AS BOOLEAN)    AS is_start_interaction_group
,CAST(a.is_end_interaction_group   AS BOOLEAN)    AS is_end_interaction_group
,CAST(a.is_start_in_interaction  AS BOOLEAN)      AS is_start_in_interaction
,CAST(COALESCE(a.previous_in_interaction_id ,-1) AS BIGINT) AS previous_in_interaction_id
,CAST(COALESCE(a.previous_out_interaction_id,-1) AS BIGINT) AS previous_out_interaction_id
,COALESCE(CAST(CASE WHEN a.previous_in_interaction_ts  IS NOT NULL THEN CAST(a.interaction_timestamp AS LONG) - CAST(a.previous_in_interaction_ts  AS LONG) ELSE NULL END AS BIGINT),0) AS previous_in_interaction_time
,COALESCE(CAST(CASE WHEN a.previous_out_interaction_ts IS NOT NULL THEN CAST(a.interaction_timestamp AS LONG) - CAST(a.previous_out_interaction_ts AS LONG) ELSE NULL END AS BIGINT),0) AS previous_out_interaction_time
,COALESCE(b.assignee_id,-1) AS assignee_id
,COALESCE(c.group_id,-1)    AS group_id
FROM prev_io a
LEFT JOIN assignee_id b on a.ticket_id = b.ticket_id and a.interaction_timestamp >= b.effective_from and a.interaction_timestamp < b.effective_to
LEFT JOIN group_id    c on a.ticket_id = c.ticket_id and a.interaction_timestamp >= c.effective_from and a.interaction_timestamp < c.effective_to