from airflow import DAG

from datetime import datetime, timedelta
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi

default_args = {
    'owner': 'Santiago Gandolfo',
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'on_failure_callback': task_fail_slack_alert_bi
}


# Crear el DAG frecuencia diaraia
dag = create_dbt_dag(
    dag_id='dbt_marketing_daily_afternoon',
    schedule_interval_tag='daily-morning',
    initial_load=False,
    default_args=default_args,
    tags=['marketing', 'daily-afternoon']
)
