{% macro format_phone_e164(country_col, area_col, number_col) %}
{# Format a phone number in E.164 format: +{country}{area}{number} #}
(
    with
    raw_data as (
        select
            coalesce(cast({{ country_col }} as string), '') as raw_country,
            coalesce(cast({{ area_col }} as string), '') as raw_area,
            coalesce(cast({{ number_col }} as string), '') as raw_number
    ),

    phone_number_without_non_numeric_characters as (
        select
            raw_country,
            raw_number,
            regexp_replace(raw_country, '[^0-9]', '') as country,
            regexp_replace(raw_area, '[^0-9]', '') as area,
            regexp_replace(raw_number, '[^0-9]', '') as number
        from raw_data
    ),

    phone_number_without_leading_zeros as (
        select
            raw_country,
            raw_number,
            regexp_replace(p.country, '^0+', '') as country,
            regexp_replace(p.area, '^0+', '') as area,
            regexp_replace(p.number, '^0+', '') as number
        from phone_number_without_non_numeric_characters as p
    ),

    phone_number_extraction as (
        select
            case
                -- Case 1: Country field contains complete phone (10+ digits, misplaced data)
                when country != '' and length(country) >= 10 then
                    country

                -- Case 2: Number already contains country code (duplication detected)
                when number != '' and length(number) >= 10
                    and country != '' and length(country) <= 3
                    and number like concat(country, '%') then
                    number

                -- Case 3: Number already contains area code (duplication detected)
                when number != '' and length(number) >= 10
                    and area != '' and number like concat(area, '%') then
                    case
                        when country != '' and length(country) <= 3 then
                            concat(country, number)
                        else
                            number
                    end

                -- Case 4: Valid separated components (country + area + number)
                when country != '' and length(country) <= 3
                    and area != '' and number != '' then
                    concat(country, area, number)

                -- Case 5: Country + number (no area available)
                when country != '' and length(country) <= 3
                    and number != '' and area = '' then
                    concat(country, number)

                -- Case 6: Area + number (no country available)
                when area != '' and number != '' and country = '' then
                    concat(area, number)

                -- Case 7: Only number field with 10+ digits
                when number != '' and length(number) >= 10 then
                    number

                else null
            end as phone_digits
        from phone_number_without_leading_zeros
    )

    select
        case
            when phone_digits is not null
                and length(phone_digits) between 9 and 15
                then concat('+', phone_digits)
            else null
        end as phone
    from phone_number_extraction
)
{% endmacro %}

