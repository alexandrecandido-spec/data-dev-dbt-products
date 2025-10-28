SELECT
  id AS group_id,
  url AS group_url,
  name AS group_name,
  description AS group_description,
  default AS is_default,  
  deleted AS is_deleted,
  created_at AS group_created_at,
  updated_at AS group_updated_at
FROM {{ source("int_zendesk_support_prod", "groups") }}