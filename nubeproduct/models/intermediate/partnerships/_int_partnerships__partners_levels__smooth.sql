WITH seq_by_partner AS 
(
  SELECT
    partner_id,
    -- armamos una lista ordenada por fecha: [{snapshot_date, raw_rank}, ...]
    sort_array(
      collect_list(named_struct('snapshot_date', snapshot_date, 'raw_rank', raw_rank))
    ) AS seq
  FROM {{ ref('int_partnerships__partners_levels__raw') }} AS RL
  GROUP BY partner_id
),
seq_arrays AS 
(
  SELECT
    partner_id,
    transform(seq, x -> x.snapshot_date) AS date_seq,  -- [fecha1, fecha2, ...]
    transform(seq, x -> x.raw_rank) AS raw_seq    -- [r1, r2, ...]
  FROM seq_by_partner
),
seq_smoothed AS 
(
  SELECT
    partner_id,
    date_seq,
    raw_seq,
    aggregate(
      raw_seq,                 -- recorré esta lista: [0,4,4,4,...]
      array<int>(),            -- arranca con una lista vacía: acc = []
      (acc, r) ->
        array_concat(
          acc,
          array(
            CASE
              WHEN cardinality(acc) = 0 THEN r   -- primer mes: smooth = raw
              ELSE
                CASE
                  WHEN r > element_at(acc, cardinality(acc)) 
                    THEN element_at(acc, cardinality(acc)) + 1  -- sube máx 1
                  WHEN r < element_at(acc, cardinality(acc)) 
                    THEN element_at(acc, cardinality(acc)) - 1  -- baja máx 1
                  ELSE element_at(acc, cardinality(acc))        -- se queda igual
                END
            END
          )
        )
    ) AS smooth_seq           -- resultado: [0,1,2,3,4] por ejemplo
  FROM seq_arrays
),
final_levels AS 
(
  SELECT
    RL.partner_id,
    RL.partner_country_code,
    RL.snapshot_date,
    RL.active_paying_stores,
    RL.new_payments_last_quarter,
    RL.new_payments_last_365d,
    RL.partner_level_raw,
    RL.raw_rank,
    element_at(SS.smooth_seq, PE.pos + 1) AS smooth_rank
  FROM seq_smoothed SS
  -- explota date_seq en filas: una fila por (partner, posición, fecha)
  LATERAL VIEW posexplode(SS.date_seq) PE AS pos, snapshot_date
  INNER JOIN {{ ref('int_partnerships__partners_levels__raw') }} AS RL
    ON RL.partner_id     = SS.partner_id
   AND RL.snapshot_date  = PE.snapshot_date
)
SELECT 
    FL.*,
    IF(LR.level IS NOT NULL, LR.level, 'Rules undefined for partners country') AS partner_level
FROM final_levels AS FL
LEFT JOIN {{ ref('int_partnerships__partners_levels__rules') }} AS LR
    ON LR.country_code = FL.partner_country_code
     AND FL.smooth_rank = LR.raw_rank