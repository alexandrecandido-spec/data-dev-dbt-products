WITH 
 base AS 
(
SELECT
 ticket_id
,created_at
,from_json(main_topic,      'array<string>') AS main_arr
,from_json(secondary_topic, 'array<string>') AS sec_arr
,from_json(replace(subtopic,'::_','___'), 'array<string>') AS sub_arr
FROM {{ ref('s__general__zendesk_tickets_label__ref') }}
WHERE subtopic is not null
{% if is_incremental() %}
    AND sys_audit_updated_on >= (SELECT COALESCE(MAX(DATE(sys_audit_updated_on)), DATE('1900-01-01')) FROM {{ this }})
{% endif %}
)
,exploded AS 
(
SELECT
 ticket_id
,created_at
,pos
,element_at(sec_arr, pos + 1) AS secondary_raw
,sub_elem AS subtopic_raw
FROM base
LATERAL VIEW posexplode(sub_arr) s AS pos, sub_elem
)
,normalized AS 
(
SELECT
 ticket_id
,created_at
,secondary_raw
,subtopic_raw
,lower(regexp_replace(translate(subtopic_raw,'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇçÑñ','AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn'),'[^a-z0-9]+', '')) AS subtopic_norm
FROM exploded
)
,mapped AS 
(
SELECT
 n.ticket_id
,n.created_at
,n.secondary_raw
,n.subtopic_raw
,COALESCE(m.subtopic_to, n.subtopic_raw) AS triple_final
FROM normalized n
LEFT JOIN 
(
SELECT lower(regexp_replace(translate(subtopic_from,'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇçÑñ','AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn'),'[^a-z0-9]+', '')) AS value_from_norm, subtopic_to
FROM   {{ source("data_manual", "ext__cx__cx__ticket_topics_change") }}
) m ON n.subtopic_norm = m.value_from_norm
)
SELECT
 ticket_id
,created_at
,COALESCE(INITCAP(REPLACE(SPLIT(triple_final, '___')[0], '_', ' ')),'Not Informed') AS main_topic_normalized
,COALESCE(INITCAP(REPLACE(SPLIT(triple_final, '___')[1], '_', ' ')),'Not Informed') AS secondary_topic_normalized
,COALESCE(INITCAP(REPLACE(SPLIT(triple_final, '___')[2], '_', ' ')),'Not Informed') AS subtopic_normalized
,COALESCE(subtopic_raw, 'Not Informed') AS subtopic_raw
FROM mapped