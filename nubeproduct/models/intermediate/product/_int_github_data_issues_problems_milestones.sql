    select * from (
select repo_name, issue_number, title as milestone_title, github_created_at as milestone_created_at,
sys_audit_updated_at,
row_number() over (partition by repo_name, issue_number order by github_created_at desc) as orden 
from {{ source('int_github_data', 'issue_milestone') }}
) a where orden = 1