SELECT
       INSTALLMENT_DATA.data_ref,
       CONTRACTS.store_id,
       INSTALLMENT_DATA.hub_contract_id,
       INSTALLMENT_DATA.hub_installment_id,
       INSTALLMENT_DATA.original_hub_installment_id,
       INSTALLMENT_DATA.deep_hub_installment_id,
       INSTALLMENT_DATA.installment_status,
       INSTALLMENT_DATA.installment_due_date,
       INSTALLMENT_DATA.installment_number,
       INSTALLMENT_DATA.installment_base_amount,
       INSTALLMENT_DATA.installment_principal_amount,
       INSTALLMENT_DATA.installment_interest_amount,
       INSTALLMENT_DATA.additional_late_fine,
       INSTALLMENT_DATA.additional_late_contract_interest,
       INSTALLMENT_DATA.additional_late_penalty_interest,
       INSTALLMENT_DATA.additional_late_taxes,
       INSTALLMENT_DATA.discount_pre_payment,
       INSTALLMENT_DATA.installment_interest_amount - INSTALLMENT_DATA.discount_pre_payment AS installment_accumulated_amount,
       INSTALLMENT_DATA.installment_updated_amount
  FROM {{ ref('fintech__lending__installment_present_value__snapshot_daily') }} AS INSTALLMENT_DATA
  LEFT JOIN {{ ref('fintech_contracts') }} AS CONTRACTS
         ON INSTALLMENT_DATA.hub_contract_id = CONTRACTS.hub_contract_id