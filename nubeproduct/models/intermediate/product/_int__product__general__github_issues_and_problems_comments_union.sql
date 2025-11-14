SELECT 
    *
FROM {{ ref('product__general__github_issue_comment__event') }} 
UNION ALL
SELECT 
    *
FROM {{ ref('product__general__github_problem_comment__event') }}