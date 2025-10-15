from airflow import DAG
from airflow.models import Variable
import ast
from datetime import datetime
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi
from functools import partial

SLACK_IDS= ast.literal_eval(Variable.get('slack_ids_fintech_alert'))



default_args = {
    'owner': 'Sofía Sánchez',
    'depends_on_past': False,
    'start_date': datetime(2025, 5, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)

}

dag = create_dbt_dag(
    dag_id='dbt_fintech_daily-4am',
    schedule_interval_tag='daily-4am',
    default_args=default_args,
    tags=["fintech", "daily-4am"]
)

# Crear el DAG frecuencia diaria por la mañana
dag = create_dbt_dag(
    dag_id='dbt_fintech_daily-9am',
    schedule_interval_tag='daily-9am',
    default_args=default_args,
    tags=["fintech", "daily-9am-4pm"]
)

# Crear el DAG frecuencia diaria por la tarde
dag = create_dbt_dag(
    dag_id='dbt_fintech_daily-4pm',
    schedule_interval_tag='daily-4pm',
    default_args=default_args,
    tags=["fintech", "daily-9am-4pm"]
)