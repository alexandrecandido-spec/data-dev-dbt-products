:dbt: [DBT Model Issue - PR #507]

Hey @ronald.corcho! Encontramos varios problemas al ejecutar las pruebas del modelo `s__attributes__store_identity__ref` que requieren tu revisión ya que está en el dominio `merchant`.

:warning: **Problemas encontrados:**

1. ✅ **Tag corregido** (ya pusheado): `daily-10am-10pm` → `daily-8am-8pm`

2. ⚠️ **`main_user_id` no está en `s__attributes__store_core__ref`**
   - Solución temporal: JOIN con `merchant__attributes__store_info__ref`
   - ¿Es correcto o debería estar en `store_core`?

3. ⚠️ **`mwp_invoice_info` source no tiene `store_id`**
   - Solución temporal: usar staging model `moltres__mwp_invoice_info`
   - ¿Es correcto o hay otra forma?

4. ⚠️ **`mwp_store_settings` tiene `id` no `store_id`**
   - Solución temporal: `id AS store_id`
   - ¿Es correcto que `id` = `store_id`?

5. ⚠️ **`mwp_store_settings_i18n` no tiene `store_id` directamente**
   - Solución temporal: JOIN complejo con `mwp_store_settings` usando `store_setting_id`
   - ¿Hay una forma más directa de obtener nombre/descripción?

:link: PR: https://github.com/TiendaNube/data-dev-dbt-products/pull/507

Los cambios temporales están en el intermediate `_int__attributes__store_identity.sql`. Necesitamos tu confirmación para proceder con las pruebas finales.

Gracias!

