WITH actions AS (
  SELECT 
    id,
    MAX(CASE WHEN field = 'comment_mode_is_public' THEN value END) AS comment_mode_is_public,
    MAX(CASE WHEN field = 'comment_value_html' THEN value END) AS comment_value_html,
    MAX(CASE WHEN field = 'current_tags' THEN value END) AS current_tags,
    MAX(CASE WHEN field = 'status' THEN value END) AS status,
    MAX(CASE WHEN field = 'type' THEN value END) AS restriction_type,
    MAX(CASE WHEN field = 'id' THEN value END) AS restriction_id,
    MAX(CASE WHEN field = 'ids' THEN value END) AS restriction_ids
  FROM
    (
      SELECT
        t.id,                                -- cambia por tu PK
        ex.pos,
        ex.item.field  AS field,
        ex.item.value  AS value
      FROM {{ source("int_zendesk_support_prod", "macros") }} t
      LATERAL VIEW POSEXPLODE(
        FROM_JSON(actions, 'array<struct<field:string,value:string>>')
      ) ex AS pos, item
      UNION ALL 
      SELECT
        t.id,                                -- cambia por tu PK
        ex.pos,
        ex.item.field  AS field,
        ex.item.value  AS value
      FROM {{ source("int_zendesk_support_prod", "macros") }} t
      LATERAL VIEW POSEXPLODE(
        FROM_JSON(restriction, 'array<struct<field:string,value:string>>')
      ) ex AS pos, item
    )
  WHERE field IN('comment_mode_is_public','comment_value_html','current_tags','status','type','id','ids')
)
SELECT
  macros.id AS macro_id,
  url AS macro_url,
  title AS macro_title,
  active AS is_active,
  created_at AS macro_created_at,
  updated_at AS macro_updated_at,
  description AS macro_description,
  a.comment_mode_is_public,
  a.comment_value_html,
  a.current_tags,
  a.status,
  a.restriction_type,
  a.restriction_id,
  a.restriction_ids
FROM {{ source("int_zendesk_support_prod", "macros") }} AS macros
LEFT JOIN actions AS a ON a.id = macros.id