SELECT
    partner_id,
    MAX(CASE WHEN tag_type = 'utm_campaign' THEN tag_value END) AS partner_utm_campaign,
	MAX(CASE WHEN tag_type = 'utm_source' THEN tag_value END) AS partner_utm_source,
	MAX(CASE WHEN tag_type = 'utm_medium' THEN tag_value END) AS partner_utm_medium,
	MAX(CASE WHEN tag_type = 'utm_content' THEN tag_value END) AS partner_utm_content
FROM ecosystem.partners_tags_campaign
GROUP BY 
    partner_id