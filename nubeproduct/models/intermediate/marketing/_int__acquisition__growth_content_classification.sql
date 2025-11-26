{% set manual_tables = [
    ('ext__marketing__acquisition__content_classification_br_blog', 'br_blog'),
    ('ext__marketing__acquisition__content_classification_br_cases', 'br_cases'),
    ('ext__marketing__acquisition__content_classification_br_downloadables', 'br_downloadables'),
    ('ext__marketing__acquisition__content_classification_br_tools', 'br_tools'),
    ('ext__marketing__acquisition__content_classification_latam_blog', 'latam_blog'),
    ('ext__marketing__acquisition__content_classification_latam_cases', 'latam_cases'),
    ('ext__marketing__acquisition__content_classification_latam_downloadables', 'latam_downloadables'),
    ('ext__marketing__acquisition__content_classification_latam_tools', 'latam_tools')
] %}

with unioned_sources as (

    {% for table_name, source_origin in manual_tables %}
    select
        -- 1. Keys & Identifiers
        cast(regexp_replace(full_url, '^https?://', '') as string) as full_url_normalized,
        cast(full_url as string) as full_url,
        
        -- 2. Classification Attributes
        cast(title as string) as title,
        cast(funnel_stage as string) as funnel_stage,
        cast(estimated_persona as string) as estimated_persona,
        cast(category as string) as category,
        cast(focus_keyword as string) as focus_keyword,
        cast(local_or_regional as string) as local_or_regional,
        cast(downloadable_format as string) as downloadable_format,
        cast(tool_name as string) as tool_name,
        
        -- 3. Metadata
        cast('{{ source_origin }}' as string) as source_origin

    from {{ source('data_manual', table_name) }}
    
    where full_url is not null 
      and trim(full_url) != ''

    {% if not loop.last %} union all {% endif %}
    {% endfor %}

)

select 
    full_url_normalized,
    full_url,
    title,
    funnel_stage,
    estimated_persona,
    category,
    focus_keyword,
    local_or_regional,
    downloadable_format,
    tool_name,
    source_origin
from unioned_sources

-- Si una URL aparece mas de una vez, nos quedamos con la primera arbitrariamente 
-- (ordenando por origen para mantener consistencia)
QUALIFY row_number() over (partition by full_url_normalized order by source_origin) = 1