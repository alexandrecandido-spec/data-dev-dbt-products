SELECT
    repo_name,
    issue_number,
    CAST(github_created_at AS DATE) AS created_at,
    CAST(github_closed_at AS DATE) AS closed_at,
    state,
    comments,
    author,
    html_url,
    title
FROM
    {{ source('int_github_data', 'issue') }}