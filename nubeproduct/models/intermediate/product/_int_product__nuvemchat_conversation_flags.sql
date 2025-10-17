SELECT
    co.cn_store_id,
    co.conversation_id,
    DATE(co.conversation_created_at) AS conversation_created_at,
    MAX(CASE WHEN m.message_discr = 'bot' AND ch.channel_discr <> 'playground' THEN 1 ELSE 0 END) AS has_ai_message,
    MAX(CASE WHEN m.message_discr IN ('store', 'store-image', 'store-audio') AND ch.channel_discr <> 'playground' THEN 1 ELSE 0 END) AS has_store_message,
    GREATEST(
      MAX(co.sys_audit_updated_on),
      MAX(m.sys_audit_updated_on),
      MAX(ch.sys_audit_updated_on)
    ) AS max_combined_sys_audit_updated_on
FROM {{ref('nuvem_chat__conversation')}} co
JOIN {{ref('nuvem_chat__channel')}} ch
    ON co.channel_id = ch.channel_id
JOIN {{ref('nuvem_chat__message')}} m
    ON co.conversation_id = m.conversation_id
GROUP BY 1, 2, 3




