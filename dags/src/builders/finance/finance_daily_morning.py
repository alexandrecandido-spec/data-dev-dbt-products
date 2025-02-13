from datetime import datetime, timedelta
from src.core.run_dbt_custom import create_dbt_dag

default_args = {
    'owner': 'Maria Rivas OConnor',
    'email': ['maria.rivas@tiendanube.com'],
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': True,
    'email_on_retry': True,
    'retries': 0,
    'retry_delay': timedelta(minutes=3)
}

# Crear el DAG
dag = create_dbt_dag(
    dag_id='dbt_finance_daily',
    schedule_interval_tag='daily-morning',
    initial_load=False,
    default_args=default_args,
    tags=['finance','daily-morning']
)