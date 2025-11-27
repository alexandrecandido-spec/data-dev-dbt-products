from airflow import DAG
from airflow.hooks.base import BaseHook
from airflow.operators.python import PythonOperator, get_current_context
from airflow.operators.bash import BashOperator
from airflow.exceptions import AirflowException
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
                    'threads': 15,
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

def _validate_no_plus_for_initial_load():
    """Solo se usa en el DAG con initial_load=True"""
    ctx = get_current_context()
    params = ctx.get('params', {}) or {}
    dag_run = ctx.get('dag_run')

    candidates = []
    pm = params.get('models')
    if pm:
        candidates.extend(pm if isinstance(pm, (list, tuple)) else [pm])
    if dag_run and getattr(dag_run, "conf", None):
        for key in ('models', 'select', 'exclude'):
            v = dag_run.conf.get(key)
            if v:
                candidates.extend(v if isinstance(v, (list, tuple)) else [v])

    if any('+' in str(x) for x in candidates):
        raise AirflowException(
            "Initial load with '+' selectors is forbidden. "
            "You're attempting an initial load with '+'. "
            "Remove '+' from your model selection and try again."
        )

    forbidden_conf_keys = (
        'tag', 'tags',
        'source', 'sources',
        'exclude',
        'config',
    )

    if dag_run and getattr(dag_run, "conf", None):
        used_forbidden = []
        for k in forbidden_conf_keys:
            v = dag_run.conf.get(k)
            if v not in (None, '', [], {}):
                used_forbidden.append(k)

        if used_forbidden:
            raise AirflowException(
                "Initial load does not allow the use of the following parameters in the trigger:"
                f"{', '.join(used_forbidden)}. "
                "Remove these parameters from the DAG Run configuration and try running the job again."
            )

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
    elif schedule_interval_tag == 'daily-3am':
        schedule_interval='0 3 * * *'
    elif schedule_interval_tag == 'daily-4am':
        schedule_interval='0 4 * * *'
    elif schedule_interval_tag == 'daily-4_30am':
        schedule_interval = '30 4 * * *'
    elif schedule_interval_tag == 'daily-6am':
        schedule_interval='0 6 * * *'
    elif schedule_interval_tag == 'daily-7am':
        schedule_interval='0 7 * * *'
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
    elif schedule_interval_tag == 'weekly-monday-8am':
        schedule_interval = '0 8 * * 1' 
    elif schedule_interval_tag == 'weekly-monday-9am':
        schedule_interval = '0 9 * * 1' 
    elif schedule_interval_tag == 'weekly-monday-930am':
        schedule_interval = '30 9 * * 1'
    elif schedule_interval_tag == 'weekly-monday-10am':
        schedule_interval = '0 10 * * 1' 
    elif schedule_interval_tag == 'weekly-monday-1030am':
        schedule_interval = '30 10 * * 1'
    elif schedule_interval_tag == 'monthly-1st-8am':
        schedule_interval='0 8 1 * *'
    elif schedule_interval_tag == 'monthly-1st-9am':
        schedule_interval='0 9 1 * *'
    elif schedule_interval_tag == 'monthly-1st-10AM':
        schedule_interval='5 10 1 * *'
    elif schedule_interval_tag == 'monthly-1st-11am':
        schedule_interval='0 11 1 * *'
    elif schedule_interval_tag == 'monthly-1st-12pm':
        schedule_interval = '0 12 1 * *' 
    elif schedule_interval_tag == 'monthly-2nd-10AM':
        schedule_interval='0 10 2 * *'
    elif schedule_interval_tag == 'monthly-4th-11am':
        schedule_interval='0 11 4 * *'
    elif schedule_interval_tag == 'monthly-4st-10AM':
        schedule_interval='0 10 4 * *'
    elif schedule_interval_tag == 'monthly-4th-12pm':
        schedule_interval = '0 12 4 * *'
    elif schedule_interval_tag == 'daily-1am':
        schedule_interval='0 1 * * *'
    else:
        schedule_interval=None 

    main_task_name = "_".join(tags)

    with DAG(
        dag_id=dag_id,
        schedule_interval=schedule_interval,
        default_args=default_args,
        tags=tags,
        catchup=False,
        params={"models": ["model_name"]}
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
            dbt_command='run',
            full_refresh=initial_load,
            models=[],  # se pobla en runtime
            pool='dbt_serial_pool',
        )

        test = DBTOperator(
            task_id='test_results',
            tags=tags,
            dbt_command='test',
            full_refresh=False,
            models=[],
            pool='dbt_serial_pool',
        )

        if initial_load:
            validate_no_plus = PythonOperator(
                task_id='validate_no_plus_for_initial_load',
                pool='dbt_serial_pool',
                python_callable=_validate_no_plus_for_initial_load,
            )
            setup >> create_profiles >> validate_no_plus >> task >> test
        else:
            setup >> create_profiles >> task >> test

        return dag