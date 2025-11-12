from airflow import DAG
from airflow.models import Variable
import ast
from datetime import datetime
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi
from functools import partial

SLACK_IDS= ast.literal_eval(Variable.get('slack_ids_analytics_engineer_alert'))



default_args = {
    'owner': 'Guillermo De Felice',
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)

}

default_args_renan = {
    'owner': 'Renan Ferrari',
    'depends_on_past': False,
    'start_date': datetime(2025, 8, 4),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)

}

# Crear el DAG frecuencia semanal (mixta)
dag = create_dbt_dag(
    dag_id='dbt_midmarket_weekly-monday-8am-mixed',
    schedule_interval_tag='weekly-monday-8am',
    default_args=default_args,
    tags=['midmarket', 'weekly-monday-8am-monthly-1st-11am']
)

# Crear el DAG frecuencia mensual (mixta)
dag = create_dbt_dag(
    dag_id='dbt_midmarket_monthly-1st-11am-mixed',
    schedule_interval_tag='monthly-1st-11am',
    default_args=default_args,
    tags=['midmarket', 'weekly-monday-8am-monthly-1st-11am']
)

# Crear el DAG frecuencia semanal (mixta)
dag = create_dbt_dag(
    dag_id='dbt_midmarket_weekly-monday-8am-mix',
    schedule_interval_tag='weekly-monday-8am',
    default_args=default_args,
    tags=['midmarket', 'weekly-monday-8am-monthly-1st-8am']
)

# Crear el DAG frecuencia mensual (mixta)
dag = create_dbt_dag(
    dag_id='dbt_midmarket_monthly-1st-8am-mix',
    schedule_interval_tag='monthly-1st-8am',
    default_args=default_args,
    tags=['midmarket', 'weekly-monday-8am-monthly-1st-8am']
)

# Crear el DAG frecuencia semanal
dag = create_dbt_dag(
    dag_id='dbt_midmarket_weekly-monday-9am',
    schedule_interval_tag='weekly-monday-9am',
    default_args=default_args,
    tags=['midmarket', 'weekly-monday-9am']
)

# Crear el DAG frecuencia semanal
dag = create_dbt_dag(
    dag_id='dbt_midmarket_weekly-monday-1030am',
    schedule_interval_tag='weekly-monday-1030am',
    default_args=default_args,
    tags=['midmarket', 'weekly-monday-1030am']
)

# Crear el DAG frecuencia mensual
dag = create_dbt_dag(
    dag_id='dbt_midmarket_monthly-1st-9am',
    schedule_interval_tag='monthly-1st-9am',
    default_args=default_args,
    tags=['midmarket', 'monthly-1st-9am']
)

# Crear el DAG frecuencia mensual
dag = create_dbt_dag(
    dag_id='dbt_midmarket_monthly-4th-12pm',
    schedule_interval_tag='monthly-4th-12pm',
    default_args=default_args,
    tags=['midmarket', 'monthly-4th-12pm']
)

# Crear  DAG frecuencia diaria 6am
dag = create_dbt_dag(
    dag_id='dbt_midmarket_daily-6am',
    schedule_interval_tag='daily-6am',
    default_args=default_args,
    tags=['midmarket', 'daily-6am']
)

# Crear  DAG frecuencia diaria 7am
dag = create_dbt_dag(
    dag_id='dbt_midmarket_daily-7am',
    schedule_interval_tag='daily-7am',
    default_args=default_args_renan,
    tags=['midmarket', 'daily-7am']
)

# Crear  DAG frecuencia diaria 8am
dag = create_dbt_dag(
    dag_id='dbt_midmarket_daily-8am',
    schedule_interval_tag='daily-8am',
    default_args=default_args_renan,
    tags=['midmarket', 'daily-8am']
)