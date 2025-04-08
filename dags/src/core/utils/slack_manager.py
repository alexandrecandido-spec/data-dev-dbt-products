from airflow.contrib.operators.slack_webhook_operator import SlackWebhookOperator
from airflow.models import TaskInstance
from airflow.utils.db import provide_session


def task_fail_slack_alert_bi(context,slack_ids:list=[]):
    SLACK_CONN_ID = 'dbt_slack_alert'
    channel = '#dbt-alerts'
    return _send_slack_alert(SLACK_CONN_ID, channel, context,slack_ids)

@provide_session
def get_task_logs(task_instance: TaskInstance, session=None):
    """
    Extrae los logs de la tarea desde la base de datos de Airflow.
    """
    logs = session.query(TaskInstance).filter(
        TaskInstance.dag_id == task_instance.dag_id,
        TaskInstance.task_id == task_instance.task_id,
        TaskInstance.execution_date == task_instance.execution_date
    ).first()
    
    return logs.log if logs else "No se pudo extraer el log de la base de datos."

def _send_slack_alert(conn_id: str, channel: str, context, slack_ids:list=[]):
    task_instance = context.get('task_instance')
    state = task_instance.state
    try_number = task_instance.try_number
    
    # Format mentions correctly based on ID format or prefix
    responsible_mentions = []
    for id in slack_ids:
        # Check if the ID belongs to a group (starts with 'S' for subteam)
        if str(id).startswith('S'):
            responsible_mentions.append('<!subteam^'+str(id)+'>')
        else:
            responsible_mentions.append('<@'+str(id)+'>')
    
    responsible = ','.join(responsible_mentions)
    
    # Try to get DBT-specific error from XCom
    dbt_error = task_instance.xcom_pull(key='dbt_error_details')
    
    # If no DBT error found, fall back to regular logs
    if not dbt_error:
        logs = get_task_logs(task_instance)
        error_details = logs if logs else "No se pudo extraer el error específico"
    else:
        error_details = dbt_error

    slack_msg = """
            {alert_type}
            *Task*: {task}  
            *Dag*: {dag} 
            *Execution Time*: {exec_date}  
            *Log Url*: {log_url} 
            *State*: {state}
            *Try Number*: {try_number}
            *Responsible*: {responsible}
            *DBT Error Details*: ```{error}```
            """.format(
        alert_type=':large_yellow_circle: Task Retrying...' if state == 'up_for_retry' else ':red_circle: Task Failed.',
        task=task_instance.task_id,
        dag=task_instance.dag_id,
        exec_date=context.get('execution_date'),
        log_url=task_instance.log_url,
        state=state,
        try_number=try_number,
        responsible=responsible,
        error=error_details
    )

    alert = SlackWebhookOperator(
        task_id='slack_failure_alert',
        slack_webhook_conn_id=conn_id,
        message=slack_msg,
        channel=channel
    )

    return alert.execute(context=context)

