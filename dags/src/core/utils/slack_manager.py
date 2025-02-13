from airflow.contrib.operators.slack_webhook_operator import SlackWebhookOperator
from airflow.models import TaskInstance
from airflow.utils.db import provide_session


def task_fail_slack_alert_bi(context,slack_ids:list=[]):
    SLACK_CONN_ID = 'dbt_slack_alert'
    channel = '#test-dbt-alerts'
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
    state = context.get('task_instance').state
    try_number = context.get('task_instance').try_number
    responsible = ','.join(['<@'+str(id)+'>' for id in slack_ids])
    logs = get_task_logs(context.get('task_instance'))

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
        task=context.get('task_instance').task_id,
        dag=context.get('task_instance').dag_id,
        ti=context.get('task_instance'),
        exec_date=context.get('execution_date'),
        log_url=context.get('task_instance').log_url,
        state=state,
        try_number = try_number,
        responsible = responsible,
        error = logs if logs else "No se pudo extraer el error específico de db. Esta es la otra"
    )  

    alert = SlackWebhookOperator(
        task_id='slack_failure_alert',
        slack_webhook_conn_id=conn_id,
        message=slack_msg,
        channel=channel
        )

    return alert.execute(context=context)

