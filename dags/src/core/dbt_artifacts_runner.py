from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.hooks.base import BaseHook
from datetime import datetime
import boto3
import os
import yaml

def create_profiles_yml():
    dbt_conn = BaseHook.get_connection("dbt_profiles")
    profiles_config = {
        'nubeproduct': {
            'outputs': {
                'prod': {
                    'catalog': None,
                    'host': dbt_conn.host,
                    'http_path': '/sql/1.0/warehouses/2f8b52bf3d2088a2',
                    'schema': 'data',
                    'threads': 4,
                    'token': dbt_conn.password,
                    'type': 'databricks'
                }
            },
            'target': 'prod'
        }
    }
    os.makedirs('/tmp/dbt', exist_ok=True)
    with open('/tmp/dbt/profiles.yml', 'w') as f:
        yaml.dump(profiles_config, f, default_flow_style=False)

default_args = {
    'owner': 'Rodrigo Nicolás Torres',
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
}

with DAG(
    dag_id='dbt_artifacts_runner',
    description='Ejecuta dbt run para dbt_artifacts',
    schedule_interval=None,
    catchup=False,
    default_args=default_args,
    tags=['dbt', 'artifacts', 's3']
) as dag:

    setup_project = BashOperator(
        task_id='setup_project_folder',
        bash_command="""
            rm -rf /tmp/dbt/docs/nubeproduct;
            mkdir -p /tmp/dbt/docs/nubeproduct;
            cp -R /usr/local/airflow/dags/dbt/nubeproduct/* /tmp/dbt/docs/nubeproduct/;
        """
    )

    create_profiles = PythonOperator(
        task_id='create_profiles',
        python_callable=create_profiles_yml
    )

    run_dbt_artifacts = BashOperator(
        task_id='run_dbt_artifacts',
        bash_command="""
            source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;
            cd /tmp/dbt/docs/nubeproduct;
            dbt deps;
            dbt run --select dbt_artifacts --project-dir . --profiles-dir /tmp/dbt;
        """
    )

    setup_project >> create_profiles >> run_dbt_artifacts