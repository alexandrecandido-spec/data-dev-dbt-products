WITH raw_tickets AS 
(
SELECT 
  id,
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
  satisfaction_rating,
  sharing_agreement_ids,
  submitter_id,
  type,
  element_at(
  filter(
    from_json(custom_fields, 'array<struct<id: BIGINT, value: STRING>>'),
    x -> x.id = 9470656687892       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS is_partner,
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
    x -> x.id IN('7553360536212','7060889383060')       -- ← el ID que buscás (numérico)
  ),
  1
  ).value AS main_topic
FROM raw.zendesk_support_prod.tickets
)
SELECT 
  *,
  CASE
    WHEN sla IS NULL OR lower(sla) = 'x' THEN NULL
    WHEN sla LIKE '%h' THEN CAST(regexp_replace(sla, '[^0-9]', '') AS INT) * 60
    WHEN sla LIKE '%m' THEN CAST(regexp_replace(sla, '[^0-9]', '') AS INT)
  ELSE NULL
END AS sla_minutos 
FROM raw_tickets
