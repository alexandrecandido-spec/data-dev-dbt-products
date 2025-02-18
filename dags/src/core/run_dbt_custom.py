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
                'dev': {
                    'catalog': None,
                    'host': dbt_conn.host,
                    'http_path': '/sql/1.0/warehouses/2f8b52bf3d2088a2',
                    'schema': 'dp',
                    'threads': 4,
                    'token': dbt_conn.password,
                    'type': 'databricks'
                }
            },
            'target': 'dev'
        }
    }
    
    # Create profiles.yml in tmp directory
    with open('/tmp/dbt/profiles.yml', 'w') as f:
        yaml.dump(profiles_config, f, default_flow_style=False)


def create_dbt_dag(
    dag_id: str,
    schedule_interval_tag: str,
    initial_load: bool,
    default_args: dict,
    tags: list
):
    """
    Función factory para crear DAGs de DBT con manejo de errores y TaskGroups
    
    Args:
        dag_id: ID del DAG
        schedule_interval: Intervalo de ejecución
        default_args: Argumentos por defecto del DAG
        models_groups: Lista de grupos de modelos a ejecutar en orden
        group_labels: Lista opcional de etiquetas para los grupos de tareas
    """
    
    """Continuar sumando condiciones de acuerdo a los schedules/tags"""
    if schedule_interval_tag == 'daily-morning':
        schedule_interval='0 9 * * *'
    elif schedule_interval_tag == 'monthly':
        schedule_interval='5 3 1 * *'
    else:
        schedule_interval=None 

    main_task_name = "_".join(tags)
    
    with DAG(
        dag_id=dag_id,
        schedule_interval=schedule_interval,
        default_args=default_args,
        tags=tags,
        catchup=False
    ) as dag:

        # Task de preparación
        setup = BashOperator(
            task_id='setup_environment',
            bash_command=f"""
                rm -rf /tmp/dbt/{main_task_name}/nubeproduct;
                mkdir -p /tmp/dbt/{main_task_name}/nubeproduct;
                mkdir -p /tmp/dbt/target; 
                cp -R /usr/local/airflow/dags/dbt/nubeproduct/* /tmp/dbt/{main_task_name}/nubeproduct/;
            """
        )
        
        create_profiles = PythonOperator(
            task_id='create_profiles_yml',
            python_callable=create_profiles_yml
        )

        task = DBTOperator(
                         task_id=main_task_name,
                         tags=tags,
                         dbt_command= 'run',
                         full_refresh=initial_load
                     )

        test = DBTOperator(
                         task_id='test_results',
                         tags=tags,
                         dbt_command= 'test',
                         full_refresh=False
                     )
        
        setup >> create_profiles >> task >> test

        return dag


## TODO: Understand how to call src.core.run_dbt_custom from builders
from datetime import datetime, timedelta
from src.core.utils.slack_manager import task_fail_slack_alert_bi

default_args = {
    'owner': 'Maria Rivas OConnor',
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=3),
    'on_failure_callback': task_fail_slack_alert_bi
}

# Crear el DAG
dag = create_dbt_dag(
    dag_id='dbt_finance_daily',
    schedule_interval_tag='daily-morning',
    initial_load=False,
    default_args=default_args,
    tags=['finance','daily-morning']
)

# Crear el DAG
dag = create_dbt_dag(
    dag_id='dbt_finance_monthly',
    schedule_interval_tag='monthly',
    initial_load=False,
    default_args=default_args,
    tags=['finance','monthly']
)

