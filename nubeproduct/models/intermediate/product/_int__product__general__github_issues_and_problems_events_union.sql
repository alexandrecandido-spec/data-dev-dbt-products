SELECT 
    *
FROM {{ ref('product__general__github_issue_event__event') }} 
UNION ALL
SELECT 
    *
FROM {{ ref('product__general__github_problem_event__event') }}