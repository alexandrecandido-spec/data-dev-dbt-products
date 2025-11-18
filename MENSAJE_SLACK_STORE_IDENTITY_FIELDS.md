:dbt:

[DBT Model Update - PR #XXX]

Hey team! I've just created a PR to add new security and social media integration fields to the Store Identity model. Would appreciate your review!

:open_file_folder: Domain: Merchant

:bust_in_silhouette: Domain Expert: @Jhu Moretty Boggio

:technologist: Technical Review: @analytics-engineering

:link: PR Link:

PR #XXX – Add security and social media fields to s__attributes__store_identity__ref

:memo: Summary:

This PR adds 7 new fields to the `s__attributes__store_identity__ref` model to track security settings and social media integrations for stores.

**New fields added:**

• **Security & Privacy:**
  - `pixel_fb`: Indicates if store has Facebook Pixel configured (Yes/No)
  - `capi_status`: Indicates if store has Facebook CAPI (Conversions API) active (Yes/No)
  - `twofa_status`: Two-factor authentication status (Completamente desactivado / 2FA completamente activado / Parcialmente activado / No informado)

• **Social Media Integrations:**
  - `tiktok_ads`: Indicates if store has TikTok Ads installed (Yes/No)
  - `google_ads`: Indicates if store has Google Ads installed (Yes/No)
  - `google_mc`: Indicates if store has Google Merchant Center installed (Yes/No)
  - `google_user`: Indicates if store has Google User installed (Yes/No)

**Changes implemented:**

• Added new CTEs in `_int__attributes__store_identity` to calculate security and social media fields
• Updated `s__attributes__store_identity__ref` to expose the new fields
• Added new sources in `_stg__sources.yml` for social media tables (`curated.social.*`)
• Added source for Facebook Business Extension (`mwp_facebook_bussiness_extension`)
• Added source for MFA users (`bronze_risk_new_admin.auth_authentication_factors`)
• All new fields documented in `merchant__schemas.yml` with descriptions

**Data sources:**
- Facebook Pixel: `mwp_store_settings.fb_pixel`
- Facebook CAPI: `mwp_facebook_bussiness_extension` (where `capi_status = 1`)
- 2FA Status: Calculated from `wp_users` and `mfa_users` (TOTP enabled)
- Social Ads: `hive_metastore.social.*` tables (tiktok_user, google_ads_account, google_merchant_center_account, google_user)

:white_check_mark: Validations:

• `dbt build --select _int__attributes__store_identity s__attributes__store_identity__ref --full-refresh`: PASS
• `dbt build --select _int__attributes__store_identity s__attributes__store_identity__ref`: PASS
• `dbt run-operation required_docs --args '{models: "s__attributes__store_identity__ref"}'`: PASS
• All tests passing (6/6: not_null, unique)

:camera_with_flash: Screenshots attached in PR

Thanks a lot for taking a look!

