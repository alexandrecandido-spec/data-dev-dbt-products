:dbt:

[DBT Model Update - PR #507]

Hey team! I've just updated PR #507 with the requested changes and would appreciate your review. Thanks in advance!

:open_file_folder: Domain: Merchant

:bust_in_silhouette: Domain Expert: @Jhu Moretty Boggio

:technologist: Technical Review: @analytics-engineering

:link: PR Link:

PR #507 – s__attributes__store_identity__ref

:memo: Summary:

This PR refactors the Store Identity model by dividing the consolidation logic into an intermediate model and adding comprehensive quality tests.

**Changes implemented:**
• Created intermediate model `_int__attributes__store_identity` with all consolidation logic (JOINs, transformations, CTEs)
• Simplified SILVER model to only consume from intermediate and handle incremental logic
• Added quality tests for all columns:
  - Conditional tests for related fields (main_user_id ↔ user_email, doc_type ↔ doc_number)
  - Type tests for timestamps (user_registered_at, theme dates, sys_audit fields)
  - Not null tests for audit fields
  - Consistency test: first_date_config_theme <= last_date_config_theme

The model consolidates store identity information from multiple sources (contacts, documents, social media, theme) and is now more maintainable with separated concerns.

Thanks a lot for taking a look!

