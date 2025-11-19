WITH raw_tickets AS 
(
SELECT 
  id AS ticket_id,
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
  get_json_object(satisfaction_rating, '$.score') AS satisfaction_score,
  get_json_object(satisfaction_rating, '$.comment') AS satisfaction_comment,
  get_json_object(satisfaction_rating, '$.reason') AS satisfaction_reason,
  sharing_agreement_ids,
  submitter_id,
  type,
  get_json_object(via, '$.channel') AS via_channel,
  lower(element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 9470656687892       -- ← el ID que buscás (numérico)
  ),
  1
  ).value) AS is_partner,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 4417988894100       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS store_status,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 14331382696596       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS store_status_by_order,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 4419805055892       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS store_tier_np_pn,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 13924439598100       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS store_plan,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 4417024422804       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS client_segment,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 4419006925716       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS client_profile,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 9204146951188       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS team_guru,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 9204090551316       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS squad_guru,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 9204049459220       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS bu_guru,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 5714467878164       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS sla,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id IN(7553360536212,7060889383060)       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS main_topic,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id IN(7464628699028, 7061039051156)       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS secondary_topic,
    element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id IN(7464653301908, 7061077300756)       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS subtopic,
  IF(tags LIKE('%cloud-humans-csat%'),TRUE,FALSE) AS is_bot,
  IF(tags LIKE('%monitorear_consumers%') OR tags LIKE('%monitorar_consumers%'),TRUE,FALSE) AS is_automation,
  IF(tags LIKE('%closed_by_merge%'),TRUE,FALSE) AS is_merged,
  IF(tags LIKE('%spam%'),TRUE,FALSE) AS is_spam,
  IF(tags LIKE('%prueba%'),TRUE,FALSE) AS is_test,
  IF(external_id LIKE('%side_conversation%'),TRUE,FALSE) AS is_side_conversation,
  REGEXP_EXTRACT(external_id, 'ticket:(\\d+)') AS parent_ticket_id
FROM {{ source("int_zendesk_support_prod", "tickets") }}
)
SELECT 
  *,
  CASE
    WHEN sla IS NULL OR lower(sla) = 'x' THEN NULL
    WHEN sla LIKE '%h' THEN CAST(regexp_replace(sla, '[^0-9]', '') AS INT) * 60
    WHEN sla LIKE '%m' THEN CAST(regexp_replace(sla, '[^0-9]', '') AS INT)
  ELSE NULL
END AS sla_min 
FROM raw_tickets
WHERE status != 'deleted'
  AND is_spam = FALSE
  AND is_test = FALSE
