from airflow import DAG
from airflow.models import Variable
import ast
from datetime import datetime
from src.core.run_dbt_custom import create_dbt_dag
from src.core.utils.slack_manager import task_fail_slack_alert_bi
from functools import partial

SLACK_IDS= ast.literal_eval(Variable.get('slack_ids_analytics_engineer_alert'))



default_args = {
    'owner': 'Fabrizio Crivella',
    'depends_on_past': False,
    'start_date': datetime(2025, 5, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'on_failure_callback': partial(task_fail_slack_alert_bi,slack_ids=SLACK_IDS)

}

# Daily frequencies
dag = create_dbt_dag(
    dag_id='dbt_product_daily_1am',
    schedule_interval_tag='daily-1am',
    default_args=default_args,
    tags=['product','daily-1am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_2am',
    schedule_interval_tag='daily-2am',
    default_args=default_args,
    tags=['product','daily-2am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_3am',
    schedule_interval_tag='daily-3am',
    default_args=default_args,
    tags=['product','daily-3am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_4am',
    schedule_interval_tag='daily-4am',
    default_args=default_args,
    tags=['product','daily-4am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_6am',
    schedule_interval_tag='daily-6am',
    default_args=default_args,
    tags=['product','daily-6am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_8am',
    schedule_interval_tag='daily-8am',
    default_args=default_args,
    tags=['product','daily-8am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily-9am',
    schedule_interval_tag='daily-9am',
    default_args=default_args,
    tags=['product', 'daily-9am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_10am',
    schedule_interval_tag='daily-10am',
    default_args=default_args,
    tags=['product','daily-10am']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_11am',
    schedule_interval_tag='daily-11am',
    default_args=default_args,
    tags=['product','daily-11am']
)


# Daily, twice a day
dag = create_dbt_dag(
    dag_id='dbt_product_daily_9am',
    schedule_interval_tag='daily-9am',
    default_args=default_args,
    tags=['product','daily-9am-9pm']
)

dag = create_dbt_dag(
    dag_id='dbt_product_daily_9pm',
    schedule_interval_tag='daily-9pm',
    default_args=default_args,
    tags=['product','daily-9am-9pm']
)


# Weekly frequencies
dag = create_dbt_dag(
    dag_id='dbt_product_weekly-monday-9am',
    schedule_interval_tag='weekly-monday-9am',
    default_args=default_args,
    tags=['product', 'weekly-monday-9am']
)

# Monthly frequencies
dag = create_dbt_dag(
    dag_id='dbt_product_monthly-4th-12pm',
    schedule_interval_tag='monthly-4th-12pm',
    default_args=default_args,
    tags=['product', 'monthly-4th-12pm']
)