WITH seq_by_partner AS 
(
  SELECT
    partner_id,
    -- armamos una lista ordenada por fecha: [{snapshot_date, raw_rank}, ...]
    sort_array(
      collect_list(named_struct('snapshot_date', snapshot_date, 'raw_rank', raw_rank))
    ) AS seq
  FROM {{ ref('_int_partnerships__partners_levels__raw') }} AS RL
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
      raw_seq,                                -- recorro esta lista: [0,4,4,4,...]
      CAST(array() AS array<int>),            -- seed tipado: acc = []
      (acc, r) ->
        concat(
          acc,
          array(
            CASE
              --WHEN size(acc) = 0 THEN r       -- primer mes: smooth = raw
              WHEN size(acc) = 0 THEN least(r, 1)
              ELSE
                CASE
                  WHEN r > element_at(acc, size(acc))
                    THEN element_at(acc, size(acc)) + 1   -- sube máx +1
                  WHEN r < element_at(acc, size(acc))
                    THEN element_at(acc, size(acc)) - 1   -- baja máx -1
                  ELSE element_at(acc, size(acc))         -- se queda igual
                END
            END
          )
        )
    ) AS smooth_seq    
  FROM seq_arrays
),
seq_exploded AS (
  SELECT
    ss.partner_id,
    s.date_seq   AS snapshot_date,
    s.smooth_seq AS smooth_rank
  FROM seq_smoothed ss
  LATERAL VIEW posexplode(arrays_zip(ss.date_seq, ss.smooth_seq)) pe AS pos, s
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
    SE.smooth_rank
  FROM seq_exploded SE
  INNER JOIN {{ ref('_int_partnerships__partners_levels__raw') }} AS RL
    ON RL.partner_id     = SE.partner_id
   AND RL.snapshot_date  = SE.snapshot_date
)
SELECT 
    FL.partner_id,
    FL.partner_country_code,
    FL.snapshot_date,
    FL.active_paying_stores,
    FL.new_payments_last_quarter,
    FL.new_payments_last_365d,
    FL.partner_level_raw,
    FL.raw_rank,
    IF(LR.level IS NOT NULL, LR.level, 'Rules undefined for partners country') AS partner_level,
    FL.smooth_rank
FROM final_levels AS FL
LEFT JOIN {{ ref('_int_partnerships__partners_levels__rules') }} AS LR
    ON LR.country_code = FL.partner_country_code
     AND FL.smooth_rank = LR.raw_rank