SELECT 
    *
FROM {{ ref('product__general__github_issue_label__link') }} 
UNION ALL
SELECT 
    *
FROM {{ ref('product__general__github_problem_label__link') }}