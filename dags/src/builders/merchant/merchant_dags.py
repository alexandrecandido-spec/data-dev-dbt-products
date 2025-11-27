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
    'start_date': datetime(2025, 10, 21),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)

}

# Crear el DAG frecuencia diaria 6am
dag = create_dbt_dag(
    dag_id='dbt_merchant_daily-6am',
    schedule_interval_tag='daily-6am',
    default_args=default_args,
    tags=['merchant','daily-6am']
)

# Crear el DAG frecuencia diaria 8am
dag = create_dbt_dag(
    dag_id='dbt_merchant_daily-8am',
    schedule_interval_tag='daily-8am',
    default_args=default_args,
    tags=['merchant','daily-8am-8pm']
)

# Crear el DAG frecuencia diaria 8pm
dag = create_dbt_dag(
    dag_id='dbt_merchant_daily-8pm',
    schedule_interval_tag='daily-8pm',
    default_args=default_args,
    tags=['merchant','daily-8am-8pm']
)

# Crear el DAG frecuencia diaria 9am
dag = create_dbt_dag(
    dag_id='dbt_merchant_daily-9am',
    schedule_interval_tag='daily-9am',
    default_args=default_args,
    tags=['merchant','daily-9am']
)

# Crear el DAG frecuencia diaria 8am
dag = create_dbt_dag(
    dag_id='dbt_merchant_daily-10am',
    schedule_interval_tag='daily-10am',
    default_args=default_args,
    tags=['merchant','daily-10am-10pm']
)

# Crear el DAG frecuencia diaria 8pm
dag = create_dbt_dag(
    dag_id='dbt_merchant_daily-10pm',
    schedule_interval_tag='daily-10pm',
    default_args=default_args,
    tags=['merchant','daily-10am-10pm']
)