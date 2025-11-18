Creé la PR #485 con los cambios solicitados para `s__product_marketing__payments__ref`:

:white_check_mark: Cambios implementados:

• Eliminado tag 'marketing' del config (solo queda 'daily_7am')

• Cambiado `company_metrics_merchant_info` → `s__attributes__store_core__ref` (2 lugares)

• Agregadas comillas a metadatos en YAML (owner, domain, business_owner)

• Agregada fuente `stg_payments.journal_payment_provider` a `_stg__sources.yml`

:white_check_mark: Validaciones:

• `dbt build --select s__product_marketing__payments__ref --full-refresh`: PASS

• `dbt build --select s__product_marketing__payments__ref`: PASS

• `dbt run-operation required_docs`: PASS

• Todos los tests pasando (4/4)

:camera_with_flash: Screenshots adjuntos en la PR

:link: https://github.com/TiendaNube/data-dev-dbt-products/pull/485

Lista para revisión

