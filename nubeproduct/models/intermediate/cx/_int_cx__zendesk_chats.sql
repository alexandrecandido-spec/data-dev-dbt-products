SELECT
  y.actor_id,
  y.actor_type,
  y.audit_id,
  ROW_NUMBER() OVER (PARTITION BY y.ticket_id ORDER BY y.ts ASC, y.audit_id ASC, y.message_id ASC) - 1 AS index,
  date_format(y.ts, 'yyyy-MM-dd HH:mm:ss.SSS') AS timestamp,
  y.ticket_id,
  y.airbyte_extracted_at
FROM (
  SELECT
    x.ticket_id,
    CAST(x.actor_id AS STRING) AS actor_id,
    x.actor_type,
    MIN(x.audit_id)            AS audit_id,
    MIN(x.ts)                  AS ts,
    x.message_id,
    MAX(x.airbyte_extracted_at) AS airbyte_extracted_at
  FROM (
    SELECT
      t.ticket_id,
      CAST(t.id AS STRING) AS audit_id,
      h.actor_id,
      h.actor_type,
      h.message_id,
      COALESCE(
        to_timestamp(regexp_replace(h.om_received, 'Z$', ''), "yyyy-MM-dd'T'HH:mm:ss.SSS"),
        to_timestamp(regexp_replace(h.received,    'Z$', ''), "yyyy-MM-dd'T'HH:mm:ss.SSS"),
        timestamp_millis(h.ts_ms),
        to_timestamp(t.created_at, "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
      ) AS ts,
      date(t._airbyte_extracted_at) AS airbyte_extracted_at
    FROM raw.zendesk_support_prod.ticket_audits t
    LATERAL VIEW OUTER explode(
      flatten(
        transform(
          filter(
            from_json(
              t.events,
              'array<
                 struct<
                   type:string,
                   value:struct<
                     history:array<
                       struct<
                         actor_id:string,
                         actor_type:string,
                         chat_index:int,
                         received:string,
                         message_id:string,
                         type:string,
                         original_message:struct<received:string>,
                         timestamp:bigint
                       >
                     >
                   >
                 >
               >'
            ),
            e -> e.value.history IS NOT NULL
          ),
          e -> transform(e.value.history, h ->
                 named_struct(
                   "actor_id",   h.actor_id,
                   "actor_type", h.actor_type,
                   "received",   h.received,
                   "om_received",h.original_message.received,
                   "message_id", h.message_id,
                   "ts_ms",      h.timestamp,
                   "type",       h.type
                 )
               )
        )
      )
    ) ev AS h
    WHERE h.message_id IS NOT NULL
      AND h.type = 'ChatMessage'
  ) x
  GROUP BY x.ticket_id, x.actor_id, x.actor_type, x.message_id
) y