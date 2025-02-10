from core.utils.slack_manager import SlackManager

def check_task_status(previous_task, **context):
    dag_run = context['dag_run']
    previous_ti =  dag_run.get_task_instance(previous_task)
    print(f"{previous_ti} is previous task status")
    
    if previous_ti.state in  ['failed', 'upstream']: 
        return 'repair_task'
    return 'end'

message = """This is an alert test"""


def send_alert():
    #slack_manager
    slack_manager = SlackManager(conn_id = 'dbt_slack_alert', channel = 'C072M0J12CB', slack_ids=None)
   
    send_message = slack_manager.send_slack_message(message = message, task_id='slack_message')

    return send_message