from airflow import DAG
from airflow.models import Variable
import ast
from datetime import datetime
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi
from functools import partial

SLACK_IDS= ast.literal_eval(Variable.get('slack_ids_analytics_engineer_alert'))

default_args = {
    'owner': 'ronald.corcho@tiendanube.com',
    'depends_on_past': False,
    'start_date': datetime(2025, 5, 8),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)
}

# Crear el DAG frecuencia diaria 4:30am
dag = create_dbt_dag(
    dag_id='dbt_marketing_daily-4_30am',
    schedule_interval_tag='daily-4_30am',
    default_args=default_args,
    tags=['marketing', 'daily-4_30am']
) 

# Crear el DAG frecuencia diaria 6:00am
dag = create_dbt_dag(
    dag_id='dbt_marketing_daily-6am',
    schedule_interval_tag='daily-6am',
    default_args=default_args,
    tags=['marketing', 'daily-6am']
) 

# Crear el DAG frecuencia diaria 8:00am
dag = create_dbt_dag(
    dag_id='dbt_marketing_daily-8am',
    schedule_interval_tag='daily-8am',
    default_args=default_args,
    tags=['marketing', 'daily-8am']
)

# Crear el DAG frecuencia diaria afternoon
dag = create_dbt_dag(
    dag_id='dbt_marketing_daily-9am',
    schedule_interval_tag='daily-9am',
    default_args=default_args,
    tags=['marketing', 'daily-9am']
)

# Crear el DAG frecuencia diaria afternoon
dag = create_dbt_dag(
    dag_id='dbt_marketing_daily-10am',
    schedule_interval_tag='daily-10am',
    default_args=default_args,
    tags=['marketing', 'daily-10am']
)
