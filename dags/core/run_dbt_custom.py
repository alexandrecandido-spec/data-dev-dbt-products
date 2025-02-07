from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago
from airflow.utils.task_group import TaskGroup
from datetime import datetime, timedelta
import os
import json
import logging
from core.utils.dbt_operator import DBTOperator


def create_dbt_dag(
    dag_id: str,
    schedule_interval_tag: str,
    initial_load: bool,
    default_args: dict,
    tags: list
    #group_labels: list = None  # Optional labels for the task groups
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
    else:
        schedule_interval=None 

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
            bash_command="""
                mkdir -p /tmp/dbt/state; 
                cp -R /usr/local/airflow/dags/dbt /tmp; 
            """
        )

        task = DBTOperator(
                         task_id="_".join(tags),
                         tags=tags,
                         dbt_command='run',
                         full_refresh=initial_load
                     )
        
        setup >> task
        return dag
    
        #previous_group = setup
        #task_groups = []

        # for i, models in enumerate(models_groups):
        #     group_label = (group_labels[i] if group_labels and i < len(group_labels) 
        #                  else f'model_group_{i+1}')
            
        #     with TaskGroup(group_id=f'dbt_{group_label}') as tg:
        #         model_tasks = []
                
        #         # Crear una tarea para cada modelo en el grupo
        #         for model in models:
        #             task = DBTOperator(
        #                 task_id=model,
        #                 model=model,
        #                 dbt_command='run',
        #                 full_refresh="{{ dag_run.conf.get('full_refresh', False) }}"
        #             )
        #             model_tasks.append(task)
                
        #         # # Configurar dependencias dentro del grupo si hay más de una tarea
        #         # for j in range(len(model_tasks)-1):
        #         #     model_tasks[j] >> model_tasks[j+1]
            
        #     task_groups.append(tg)
        #     previous_group >> tg
        #     previous_group = tg

        # return dag

default_args = {
    'owner': 'Maria Rivas OConnor',
    'email': ['maria.rivas@tiendanube.com'],
    'depends_on_past': False,
    'start_date': datetime(2024, 10, 1),
    'email_on_failure': True,
    'email_on_retry': True,
    'retries': 2,
    'retry_delay': timedelta(minutes=5)
}

# Grupos de modelos organizados por dependencias con etiquetas descriptivas
# model_groups = [
#     ['stg_marketing__ga4_analytics_events', 'stg_moltres__mwp_store_info'],
#     ['ga4_user_events']
# ]

# group_labels = ['staging_models', 'data_products']

# Crear el DAG
dag = create_dbt_dag(
    dag_id='dbt_finance_daily',
    schedule_interval_tag='daily-morning',
    initial_load=False,
    default_args=default_args,
    tags=['finance','daily-morning']
    #group_labels=group_labels
)

