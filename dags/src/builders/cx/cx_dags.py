from airflow import DAG
from airflow.models import Variable
import ast
from datetime import datetime
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi
from functools import partial

SLACK_IDS= ast.literal_eval(Variable.get('slack_ids_analytics_engineer_alert'))

default_args = {
    'owner': 'valeria.nascimento@nuvemshop.com.br',
    'depends_on_past': False,
    'start_date': datetime(2025, 10, 24),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)
}

# Crear el DAG frecuencia diaria 6am
dag = create_dbt_dag(
    dag_id='dbt_cx_daily-6am',
    schedule_interval_tag='daily-6am',
    default_args=default_args,
    tags=['cx', 'daily-6am']
)
