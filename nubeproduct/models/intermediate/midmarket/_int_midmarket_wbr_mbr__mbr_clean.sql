-- Owner: Guille De Felice

select
    CAST(m.date AS DATE) as date_from,
    CAST(m.date + interval '1' month - interval '1' day AS DATE) as date_to,
    store_id,
    CASE
        WHEN rep = 'ts-abiliomoura' THEN 'Abilio Moura'
        WHEN rep = 'ts-agos' THEN 'Agostina Dottori'
        WHEN rep = 'ts-agustinacoarasa' THEN 'Agustina Coarasa'
        WHEN rep = 'ts-ale' THEN 'Alejandra Vigil'
        WHEN rep = 'ts-alex' THEN 'Alex Shuster'
        WHEN rep = 'ts-alfredocontreras' THEN 'Alfredo Contreras'
        WHEN rep = 'ts-ana' THEN 'Ana Di Nucci'
        WHEN rep = 'ts-ariannygarcia' THEN 'Arianny Garcia'
        WHEN rep = 'ts-ariela' THEN 'Ariela Balista'
        WHEN rep = 'ts-azu' THEN 'Azul Araujo'
        WHEN rep = 'ts-barbara' THEN 'Bárbara Castro'
        WHEN rep = 'ts-bebel' THEN 'Bebel Queiroz'
        WHEN rep = 'ts-belu' THEN 'Maria Belen Vilchez Larrea'
        WHEN rep = 'ts-bido' THEN 'Mariano Bidoglio'
        WHEN rep = 'ts-boliveira' THEN 'Bruna DOliveira'
        WHEN rep = 'ts-brunanunes' THEN 'Bruna Nunes'
        WHEN rep = 'ts-caioferreira' THEN 'Caio Ferreira'
        WHEN rep = 'ts-carlosalmada' THEN 'Carlos Almada'
        WHEN rep = 'ts-daiane' THEN 'Daiane Kauffman'
        WHEN rep = 'ts-dayanesilva' THEN 'Dayane Silva'
        WHEN rep = 'ts-diegomateus' THEN 'Diego Mateus'
        WHEN rep = 'ts-elaine' THEN 'Elaine Campos'
        WHEN rep = 'ts-flavio' THEN 'Flávio Batista do Rozário'
        WHEN rep = 'ts-flaviorozario' THEN 'Flávio Batista do Rozário'
        WHEN rep = 'ts-florenciagalli' THEN 'Florencia Galli'
        WHEN rep = 'ts-gabrielsouza' THEN 'Gabriel Souza'
        WHEN rep = 'ts-gianbevilacqua' THEN 'Gian Bevilacqua'
        WHEN rep = 'ts-gonzaloluque' THEN 'Gonzalo Teilleri Luque'
        WHEN rep = 'ts-gustavotillet' THEN 'Gustavo Tillet'
        WHEN rep = 'ts-haiany' THEN 'Haiany Santos'
        WHEN rep = 'ts-hugogonzalez' THEN 'Hugo González'
        WHEN rep = 'ts-ine' THEN 'Inés Prato Azulay'
        WHEN rep = 'ts-ismael' THEN 'Ismael Batista'
        WHEN rep = 'ts-jona' THEN 'Jonatan Moggia'
        WHEN rep = 'ts-joyce' THEN 'Joyce Marques'
        WHEN rep = 'ts-juampi' THEN 'Juan Pablo Zucconi'
        WHEN rep = 'ts-juani' THEN 'Juan Ignacio Mehl'
        WHEN rep = 'ts-juliana' THEN 'Juliana Queiros'
        WHEN rep = 'ts-julianaaquino' THEN 'Juliana Aquino'
        WHEN rep = 'ts-julietaterradillo' THEN 'Julieta Terradillo'
        WHEN rep = 'ts-kamillamenezes' THEN 'kamilla menezes'
        WHEN rep = 'ts-kelvin' THEN 'Kelvin Castillo'
        WHEN rep = 'ts-lalita' THEN 'Lalita Silva'
        WHEN rep = 'ts-luigi' THEN 'Luis Alberto Guerra'
        WHEN rep = 'ts-luis' THEN 'Luis Trovó'
        WHEN rep = 'ts-luisa' THEN 'Luisa Ariadne'
        WHEN rep = 'ts-luiza' THEN 'Luiza Zuin'
        WHEN rep = 'ts-luizazuin' THEN 'Luiza Zuin'
        WHEN rep = 'ts-manu' THEN 'Emanuele Ramalho'
        WHEN rep = 'ts-marcelarodrigues' THEN 'Marcela Rodrigues'
        WHEN rep = 'ts-marcelo' THEN 'Marcelo Santos'
        WHEN rep = 'ts-marcos' THEN 'Marcos Figueiredo'
        WHEN rep = 'ts-mayarasilva' THEN 'Mayara Silva'
        WHEN rep = 'ts-melisabecker' THEN 'Melisa Becker'
        WHEN rep = 'ts-micu' THEN 'Micaela Sanchez'
        WHEN rep = 'ts-millie' THEN 'Millie Paz Iturralde'
        WHEN rep = 'ts-misha' THEN 'Micaela Sanchez'
        WHEN rep = 'ts-nelson' THEN 'Nelson Souza'
        WHEN rep = 'ts-nico' THEN 'Nicolás Poggi'
        WHEN rep = 'ts-paulasturm' THEN 'Paula Sturm'
        WHEN rep = 'ts-pedrofroz' THEN 'Pedro Froz'
        WHEN rep = 'ts-petri' THEN 'Petricielly Silva'
        WHEN rep = 'ts-rodrigo' THEN 'Rodrigo Guimarães'
        WHEN rep = 'ts-romi' THEN 'Romina Schneider'
        WHEN rep = 'ts-samuel' THEN 'Samuel Neiva'
        WHEN rep = 'ts-sofi' THEN 'Sofia Haro'
        WHEN rep = 'ts-soraia' THEN 'Soraia Rodrigues da Silva'
        WHEN rep = 'ts-stephanie' THEN 'Stephanie Hanashiro'
        WHEN rep = 'ts-taynahbreviglieri' THEN 'Taynah Breviglieri'
        WHEN rep = 'ts-toledo' THEN 'Regina Toledo'
        WHEN rep = 'ts-valerialima' THEN 'Valéria Lima'
        ELSE null
    END as rep,
    case 
        when lower(touch) = 'low' then 'Level 3'
        when lower(touch) = 'mid' then 'Level 2'
        when lower(touch) = 'high' then 'Level 1'
		else 'No Level'
	  end as level,
    case
        when playbook = 'Churn' then 'Warning'
        when lower(playbook) = 'effective churn' then 'Effective churn'
        when playbook = '' then null
        else playbook
    end as playbook,
    case
        when status IN ('Expansion', 'Maintenance', 'Onboarding', 'Ok') THEN 'Ok'
        when status = 'Effective Churn' then 'Effective churn'
        when status = '' then null
        else status
    end as status,
    country,
    franchise_group,
    main,
    CAST(last_relevant_interaction AS DATE) as last_relevant_interaction,
    CAST(last_group_interaction AS DATE) as last_group_interaction,
    date_diff(DAY, coalesce(last_group_interaction, last_relevant_interaction), date_to) as days_since_last_relevant_interaction,
    CAST(plan_id AS INTEGER) as plan_id,
    CAST(monthly AS INTEGER) as monthly,
    context,
    nice_name,
    ROUND(transaction_fee, 1) AS transaction_fee,
    transaction_fee_type,
    case
        when gp.grupo = 'enterprise' then true 
        else false
    end as enterprise_plan,
    type_change,
    not_unknown_reason,
    CAST(NULL AS INTEGER) as free_days
from 
    {{ source("int_data_legacy", "stitchdata__mbr_success") }} m
    left join {{ ref('operations_grouping_plans') }} gp
        on m.plan_id = gp.plan
where
    m.in_portfolio = true