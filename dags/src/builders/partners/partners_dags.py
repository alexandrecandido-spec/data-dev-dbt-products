from airflow import DAG
from airflow.models import Variable
import ast
from datetime import datetime
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi
from functools import partial

SLACK_IDS= ast.literal_eval(Variable.get('slack_ids_analytics_engineer_alert'))

default_args = {
    'owner': 'felipe.lorenzo@tiendanube.com',
    'depends_on_past': False,
    'start_date': datetime(2025, 7, 10),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)
}

# Crear el DAG frecuencia diaria 10am
dag = create_dbt_dag(
    dag_id='dbt_partners_daily-10am',
    schedule_interval_tag='daily-10am',
    default_args=default_args,
    tags=['partners', 'daily-10am']
)

# Crear el DAG frecuencia diaria 11am
dag = create_dbt_dag(
    dag_id='dbt_partners_daily-11am',
    schedule_interval_tag='daily-11am',
    default_args=default_args,
    tags=['partners', 'daily-11am']
)
