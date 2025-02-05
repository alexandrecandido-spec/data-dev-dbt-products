from airflow import DAG
from airflow.operators.bash_operator import BashOperator
from airflow.operators.python_operator import PythonOperator
from airflow.utils.dates import days_ago
from datetime import datetime, timedelta


import os

DAG_ID = os.path.basename(__file__).replace(".py", "")
default_args = {
    'owner': 'Maria Rivas OConnor',
    'email': ['maria.rivas@tiendanube.com'],
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=0)}

# assumes all files are in a subfolder of DAGs called dbt
def get_models_to_execute(**context):
    models = context['dag_run'].conf.get('models', ['+ga4_user_events'])
    mode = context['dag_run'].conf.get('mode', 'initial')
    mode_flag = '--full-refresh ' if mode == 'initial' else ''
    models_str = ''
    for model in models:
        models_str += model + ' '
    command = f"""source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;\
        cp -R /usr/local/airflow/dags/dbt /tmp;\
        echo 'listing project files:';\
        ls -R /tmp;\
        cd /tmp/dbt/nubeproduct;\
        /usr/local/airflow/python3-virtualenv/dbt-env/bin/dbt run --models {models_str}{mode_flag}--project-dir /tmp/dbt/nubeproduct --profiles-dir ..;\
        cat /tmp/dbt_logs/dbt.log;\
        rm -rf /tmp/dbt/nubeproduct"""
    return command

with DAG(dag_id=DAG_ID, 
         description='MVP Run models with config',
        tags=['data-products'],
        params={
        "execution_start": datetime.now().strftime('%Y-%m-%d'),
        "mode":"initial",
        "models": ["+ga4_user_events", "+ga4_mod_pv_info", "+test_wallet"]
        },
        schedule_interval=None, catchup=False, start_date=days_ago(1)
        ) as dag:
    get_models = PythonOperator(
        task_id='get_models',
        python_callable=get_models_to_execute
    )
    cli_command = BashOperator(
        task_id="cli_command",
        bash_command="{{ ti.xcom_pull(task_ids='get_models') }}"
    )
    
get_models >> cli_command