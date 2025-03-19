from airflow import DAG

from datetime import datetime, timedelta
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi 


default_args = {
    'owner': 'Maria Rivas OConnor',
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=0),
    'on_failure_callback': task_fail_slack_alert_bi
}

# Crear el DAG!!
dag = create_dbt_dag(
    dag_id='dbt_test_2',
    schedule_interval_tag='manual',
    initial_load=False,
    default_args=default_args,
    tags=['testing','manual']
)
