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
    dag_id='dbt_finance_daily-8_30am',
    schedule_interval_tag='daily-8_30am',
    default_args=default_args,
    tags=['finance','daily-8_30am']
)

# Criar o DAG para a frequência mensal (revenue by store)
dag_monthly = create_dbt_dag(
    dag_id='dbt_finance_monthly-4th-11am',
    schedule_interval_tag='monthly-4th-11am',
    default_args=default_args,
    tags=['finance','monthly-4th-11am']
)

# Crear el DAG frecuencia diaria (billing)
dag = create_dbt_dag(
    dag_id='dbt_finance_daily-10am',
    schedule_interval_tag='daily-10am',
    default_args=default_args,
    tags=['finance','daily-10am']
)
