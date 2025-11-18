# PR: Agregar campos a s__attributes__store_identity__ref

## Resumen
Este PR agrega nuevos campos al modelo `s__attributes__store_identity__ref` para incluir información de Facebook Pixel, CAPI, 2FA y Social Ads (TikTok, Google Ads, Google Merchant Center, Google User).

## Archivos modificados

### 1. Intermediate Model
- **`nubeproduct/models/intermediate/merchant/_int__attributes__store_identity.sql`**
  - Agregado CTE `facebook_capi` para Facebook CAPI status
  - Agregado CTE `twofa_status` para estado de 2FA por tienda
  - Agregado CTE `social_ads` para Social Ads (TikTok, Google Ads, Google MC, Google User)
  - Agregado campo `pixel_fb` en `store_settings` CTE
  - Agregados JOINs para los nuevos CTEs
  - Agregados campos al SELECT final

### 2. Silver Model
- **`nubeproduct/models/data_product/merchant/s__attributes__store_identity__ref.sql`**
  - Agregados campos al SELECT: `pixel_fb`, `capi_status`, `twofa_status`, `tiktok_ads`, `google_ads`, `google_mc`, `google_user`

### 3. Sources
- **`nubeproduct/models/staging/_stg__sources.yml`**
  - Agregado source `mwp_facebook_bussiness_extension` en `stg_moltres`
  - Agregado source `stg_curated_social` con tablas: `google_ads_account`, `google_user`, `google_merchant_center_account`, `tiktok_user`
  - Agregado source `stg_tableau_external` con tabla `gs_perfit_merchants` (para uso futuro)

### 4. Staging Models (eliminados)
- Los modelos staging para Social Ads fueron eliminados porque no son reutilizables
- La lógica se movió directamente al intermediate como CTEs (`base_tiktok`, `base_google_ads`, `base_merchant_center`, `base_google_user`)
- Esto simplifica el mantenimiento y evita materialización innecesaria (los intermediate son ephemeral)

## Campos agregados

| Campo | Tipo | Valores | Descripción |
|-------|------|---------|-------------|
| `pixel_fb` | String | 'Yes' / 'No' | Indica si la tienda tiene Facebook Pixel configurado |
| `capi_status` | String | 'Yes' / 'No' | Indica si la tienda tiene Facebook CAPI activo |
| `twofa_status` | String | 'Completamente desactivado' / '2FA completamente activado' / 'Parcialmente activado' / 'No informado' | Estado de 2FA de la tienda |
| `tiktok_ads` | String | 'Yes' / 'No' | Indica si la tienda tiene TikTok Ads instalado |
| `google_ads` | String | 'Yes' / 'No' | Indica si la tienda tiene Google Ads instalado |
| `google_mc` | String | 'Yes' / 'No' | Indica si la tienda tiene Google Merchant Center instalado |
| `google_user` | String | 'Yes' / 'No' | Indica si la tienda tiene Google User instalado |

## Fuentes de datos

- **Facebook Pixel**: `stg_moltres.mwp_store_settings.fb_pixel`
- **Facebook CAPI**: `stg_moltres.mwp_facebook_bussiness_extension` (filtrado por `deleted_at IS NULL AND capi_status = 1`)
- **2FA**: `int_moltres.wp_users` + `bronze_risk_new_admin.auth_authentication_factors` (TOTP enabled)
- **Social Ads**: Modelos staging que consumen desde `stg_curated_social.*`

## Testing
- [ ] Verificar que el modelo compila correctamente
- [ ] Verificar que los campos se populan correctamente
- [ ] Verificar incrementalidad funciona correctamente

## Notas
- La lógica de Social Ads está implementada directamente en el intermediate como CTEs (no como modelos staging separados)
- Esto sigue las mejores prácticas: staging solo para modelos reutilizables, intermediate para lógica específica de un modelo
- El source `stg_tableau_external` se agregó para uso futuro (Perfit), pero no se usa en este PR

