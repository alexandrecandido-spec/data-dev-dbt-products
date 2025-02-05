from datetime import datetime, timedelta
from ..core.run_dbt_custom import create_dbt_dag

default_args = {
    'owner': 'Maria Rivas OConnor',
    'email': ['maria.rivas@tiendanube.com'],
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': True,
    'email_on_retry': True,
    'retries': 2,
    'retry_delay': timedelta(minutes=5)
}

# Grupos de modelos organizados por dependencias con etiquetas descriptivas
model_groups = [
    ['stg_marketing__ga4_analytics_events', 'stg_moltres__mwp_store_info'],
    ['ga4_user_events']
]

group_labels = ['staging_models', 'data_products']

# Crear el DAG
dag = create_dbt_dag(
    dag_id='dbt_ga4_run',
    schedule_interval=None,
    default_args=default_args,
    models_groups=model_groups,
    group_labels=group_labels
)