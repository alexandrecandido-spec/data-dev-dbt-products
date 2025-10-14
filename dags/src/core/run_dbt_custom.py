from airflow import DAG
from airflow.hooks.base import BaseHook
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

import yaml
from src.core.utils.dbt_operator import DBTOperator



def create_profiles_yml():
    """Construye profiles.yml con los detalles de conexión en Airflow"""
    dbt_conn = BaseHook.get_connection("dbt_profiles")
    
    profiles_config = {
        'nubeproduct': {
            'outputs': {
                'prod': {
                    'catalog': 'data_products_prd',
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
    
    # Create profiles.yml in tmp directory
    with open('/tmp/dbt/profiles.yml', 'w') as f:
        yaml.dump(profiles_config, f, default_flow_style=False)


def create_dbt_dag(
    dag_id: str,
    schedule_interval_tag: str,
    default_args: dict,
    tags: list,
    initial_load: bool = False
):
    """
    Función factory para crear DAGs de DBT con manejo de errores y TaskGroups
    
    Args:
        dag_id: ID del DAG
        schedule_interval: Intervalo de ejecución
        default_args: Argumentos por defecto del DAG
        tags: Lista de etiquetas de modelos a ejecutar, condicion de tipo AND
        initial_load: Indica si la ejecución debe ser inicial o incremental
    """
    
    """Continuar sumando condiciones de acuerdo a los schedules/tags"""
    if schedule_interval_tag == 'daily-2am':
        schedule_interval='0 2 * * *'
    elif schedule_interval_tag == 'daily-4am':
        schedule_interval='0 4 * * *'
    elif schedule_interval_tag == 'daily-4_30am':
        schedule_interval = '30 4 * * *'
    elif schedule_interval_tag == 'daily-6am':
        schedule_interval='0 6 * * *'
    elif schedule_interval_tag == 'daily-10am':
        schedule_interval='0 10 * * *'
    elif schedule_interval_tag == 'daily-8am':
        schedule_interval='0 8 * * *'
    elif schedule_interval_tag == 'daily-8_30am':
        schedule_interval='30 8 * * *'
    elif schedule_interval_tag == 'daily-9am':
        schedule_interval='0 9 * * *'
    elif schedule_interval_tag == 'daily-10am':
        schedule_interval='0 10 * * *'
    elif schedule_interval_tag == 'daily-12pm':
        schedule_interval='0 12 * * *'
    elif schedule_interval_tag == 'daily-4pm':
        schedule_interval='0 19 * * *'
    elif schedule_interval_tag == 'daily-6pm':
        schedule_interval='0 18 * * *'
    elif schedule_interval_tag == 'daily-8pm':
        schedule_interval='0 20 * * *'
    elif schedule_interval_tag == 'daily-9pm':
        schedule_interval='0 21 * * *'
    elif schedule_interval_tag == 'weekly-monday-9am':
        schedule_interval = '0 9 * * 1' 
    elif schedule_interval_tag == 'weekly-monday-10am':
        schedule_interval = '0 10 * * 1' 
    elif schedule_interval_tag == 'weekly-monday-1030am':
        schedule_interval = '30 10 * * 1'
    elif schedule_interval_tag == 'monthly-1st-10AM':
        schedule_interval='5 10 1 * *'
    elif schedule_interval_tag == 'monthly-1st-12pm':
        schedule_interval = '0 12 1 * *' 
    elif schedule_interval_tag == 'monthly-2nd-10AM':
        schedule_interval='0 10 2 * *'
    elif schedule_interval_tag == 'monthly-4th-11am':
        schedule_interval='0 11 4 * *'
    elif schedule_interval_tag == 'monthly-4st-10AM':
        schedule_interval='0 10 4 * *'
    else:
        schedule_interval=None 

    main_task_name = "_".join(tags)
    
    with DAG(
        dag_id=dag_id,
        schedule_interval=schedule_interval,
        default_args=default_args,
        tags=tags,
        catchup=False,
        params={
        "models": ["model_name"]    
        }
    ) as dag:

        # Task de preparación
        setup = BashOperator(
            task_id='setup_environment',
            pool='dbt_serial_pool',
            bash_command=f"""
                rm -rf /tmp/dbt/{main_task_name}/nubeproduct;
                mkdir -p /tmp/dbt/{main_task_name}/nubeproduct;
                mkdir -p /tmp/dbt/target; 
                cp -R /usr/local/airflow/dags/dbt/nubeproduct/* /tmp/dbt/{main_task_name}/nubeproduct/;
            """
        )
        
        create_profiles = PythonOperator(
            task_id='create_profiles_yml',
            pool='dbt_serial_pool',
            python_callable=create_profiles_yml
        )

        task = DBTOperator(
                         task_id=main_task_name,
                         tags=tags,
                         dbt_command= 'run',
                         full_refresh=initial_load,
                         models=[],  # Empty by default, will be populated at runtime
                         pool='dbt_serial_pool',
                     )

        test = DBTOperator(
                         task_id='test_results',
                         tags=tags,
                         dbt_command= 'test',
                         full_refresh=False,
                         models=[],  # Empty by default, will be populated at runtime
                         pool='dbt_serial_pool',
                     )
        
        setup >> create_profiles >> task >> test

        return dag
