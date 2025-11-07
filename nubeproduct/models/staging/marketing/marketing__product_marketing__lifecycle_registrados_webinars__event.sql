{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['id'],                           
  partition_by=['year_month_day_code'],
  on_schema_change='fail',
  tags=['daily-6am','marketing']
) }}

-- 0) estado actual (para preservar created_* y evitar upsert si no cambió)
WITH existing AS (
  {% if is_incremental() %}
  SELECT
    CAST(id AS {{ dbt.type_string() }}) AS id,
    row_hash,
    sys_audit_created_on,
    sys_audit_created_by
  FROM {{ this }}
  {% else %}
  SELECT
    CAST(NULL AS {{ dbt.type_string() }}) AS id,
    CAST(NULL AS {{ dbt.type_string() }}) AS row_hash,
    CAST(NULL AS TIMESTAMP)               AS sys_audit_created_on,
    CAST(NULL AS {{ dbt.type_string() }}) AS sys_audit_created_by
  WHERE 1=0
  {% endif %}
),

-- 1) wp_users normalizado: email, store, fechas y ID
wp AS (
  SELECT
    LOWER(TRIM(user_email))                      AS email_lc,
    CAST(store_id AS BIGINT)                     AS store_id,
    CAST(ID AS BIGINT)                           AS wp_user_id,
    CAST(account_confirmed_at AS TIMESTAMP)      AS account_confirmed_at,
    CAST(user_registered      AS TIMESTAMP)      AS user_registered
  FROM {{ source('stg_moltres','wp_users') }}
  WHERE user_email IS NOT NULL AND TRIM(user_email) <> ''
),

-- 2) elegir UNA store por email:
--    1) max(COALESCE(account_confirmed_at, user_registered))
--    2) si empata: store_id más alto
--    3) si empata: wp_user_id más alto
email_pick AS (
  SELECT email_lc, store_id
  FROM (
    SELECT
      w.*,
      ROW_NUMBER() OVER (
        PARTITION BY w.email_lc
        ORDER BY COALESCE(w.account_confirmed_at, w.user_registered) DESC,
                 w.store_id DESC,
                 w.wp_user_id DESC
      ) AS rn
    FROM wp w
  ) x
  WHERE rn = 1
),

-- 3) crudo de webinars + mapping determinístico a store_id
raw AS (
  SELECT
    ep.store_id                                                            AS store_id,
    CASE WHEN ep.store_id IS NOT NULL THEN 'email' ELSE 'none' END         AS mapping_method,

    -- crudos (normalizados)
    CAST(w.id AS {{ dbt.type_string() }})                                  AS id,
    LOWER(TRIM(w.email))                                                   AS email,
    w.firstName, w.lastName, w.phone,
    LOWER(TRIM(w.status))                                                  AS status,
    w.webinar,
    {{ marketing_mpt_parse_ts("w.webinar_date") }} AS webinar_date,
    NULLIF(TRIM(w.webinar_code),'')                                        AS webinar_code,
    w.country
  FROM {{ source('stg_unity_data_manual','ext__marketing__product_marketing__lifecycle_registrados_webinars') }} w
  LEFT JOIN email_pick ep
    ON ep.email_lc = LOWER(TRIM(w.email))
),

-- 4) partición (evitar NULL en partición)
with_keys AS (
  SELECT
    r.*,
    CAST(
      date_format(
        COALESCE(CAST(r.webinar_date AS DATE), current_date),
        'yyyyMMdd'
      ) AS INT
    ) AS year_month_day_code
  FROM raw r
),


-- 5) row_hash con "todos los campos de negocio" (sin sys_audit_* ni partición)
with_hash AS (
  SELECT
    wk.*,
    {{ mpt_hash([
      "wk.store_id",
      "wk.mapping_method",
      "wk.id",
      "wk.email",
      "wk.firstName",
      "wk.lastName",
      "wk.phone",
      "wk.status",
      "wk.webinar",
      "CAST(wk.webinar_date AS DATE)",
      "COALESCE(wk.webinar_code, '')",
      "wk.country"
    ]) }} AS row_hash
  FROM with_keys wk
),

-- 6) upsert solo si (id no existe) o (hash cambió). Preservamos created_*.
to_upsert AS (
  SELECT
    wh.store_id, wh.mapping_method,
    wh.id, wh.email, wh.firstName, wh.lastName, wh.phone,
    wh.status, wh.webinar, wh.webinar_date, wh.webinar_code, wh.country,
    wh.year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp)         AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by,  'data-dev-dbt-marketing') AS sys_audit_created_by,
    current_timestamp                                            AS sys_audit_updated_on,
    'data-dev-dbt-marketing'                                     AS sys_audit_updated_by,
    wh.row_hash
  FROM with_hash wh
  LEFT JOIN existing e USING (id)
  WHERE e.row_hash IS NULL OR e.row_hash <> wh.row_hash
)

SELECT *
FROM to_upsert