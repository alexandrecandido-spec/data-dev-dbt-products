from airflow import DAG
from airflow.models import Variable
import ast
from datetime import datetime
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi
from functools import partial

SLACK_IDS= ast.literal_eval(Variable.get('slack_ids_analytics_engineer_alert'))



default_args = {
    'owner': 'Rodrigo Nicolás Torres',
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)

}

# Crear el DAG frecuencia diaria
dag = create_dbt_dag(
    dag_id='dbt_finance_daily-4am',
    schedule_interval_tag='daily-4am',
    default_args=default_args,
    tags=['finance','daily-4am']
)