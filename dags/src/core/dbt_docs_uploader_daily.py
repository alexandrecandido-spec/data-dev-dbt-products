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

def upload_docs_to_s3():
    s3 = boto3.client('s3')
    bucket_name = 'dn-dbtdp-artif-prd01'
    s3_prefix = 'dbt_artifacts/'
    target_dir = '/tmp/dbt/docs/nubeproduct/target'
    
    for file_name in ['manifest.json', 'catalog.json']:
        local_path = os.path.join(target_dir, file_name)
        if os.path.exists(local_path):
            s3.upload_file(local_path, bucket_name, f'{s3_prefix}{file_name}')
        else:
            raise FileNotFoundError(f"{local_path} no encontrado")

default_args = {
    'owner': 'Rodrigo Nicolás Torres',
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
}

with DAG(
    dag_id='dbt_docs_uploader_daily',
    description='Genera dbt docs y sube manifest/catalog a S3',
    schedule_interval='0 3 * * *',
    catchup=False,
    default_args=default_args,
    tags=['dbt', 'docs', 's3']
) as dag:

    setup_docs = BashOperator(
        task_id='setup_docs_folder',
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

    generate_docs = BashOperator(
        task_id='generate_dbt_docs',
        bash_command="""
            source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;
            cd /tmp/dbt/docs/nubeproduct;
            dbt deps;
            dbt docs generate --project-dir . --profiles-dir /tmp/dbt;
        """
    )

    upload_to_s3 = PythonOperator(
        task_id='upload_docs_to_s3',
        python_callable=upload_docs_to_s3
    )

    setup_docs >> create_profiles >> generate_docs >> upload_to_s3
