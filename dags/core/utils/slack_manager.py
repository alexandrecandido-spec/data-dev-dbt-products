from airflow.hooks.base_hook import BaseHook
from airflow.contrib.operators.slack_webhook_operator import SlackWebhookOperator


class SlackManager:
    def __init__(self, conn_id, channel=None, slack_ids=None):
        self.conn_id = conn_id
        self.channel = channel
        self.slack_ids = slack_ids or []



    def send_slack_message(self, message, task_id='slack_message'):
        if self.slack_ids:
            message = f'{message}\n CC: {self.get_slack_mentions()}' # is equivalent to: message = message + '\n CC: ' + self.get_slack_mentions()
        alert = self.get_operator(message, task_id)
        return alert.execute(context=None)

    def get_operator(self, message, task_id):
        slack_webhook_token = BaseHook.get_connection(self.conn_id).password

        alert = SlackWebhookOperator(
            task_id=task_id,
            http_conn_id=self.conn_id,
            webhook_token=slack_webhook_token,
            message=message,
            channel=self.channel
        )
        
        return alert

    def send_slack_alert(self, context):
        state = context.get('task_instance').state
        try_number = context.get('task_instance').try_number
        responsible = self.get_slack_mentions()

        slack_msg = """
                {alert_type}
                *Task*: {task}  
                *Dag*: {dag} 
                *Execution Time*: {exec_date}  
                *Log Url*: {log_url} 
                *State*: {state}
                *Try Number*: {try_number}
                *Responsible*: {responsible}
                """.format(
            alert_type=':large_yellow_circle: Task Retrying...' if state == 'up_for_retry' else ':red_circle: Task Failed.',
            task=context.get('task_instance').task_id,
            dag=context.get('task_instance').dag_id,
            ti=context.get('task_instance'),
            exec_date=context.get('execution_date'),
            log_url=context.get('task_instance').log_url,
            state=state,
            try_number = try_number,
            responsible = responsible
        )  
        return self.send_slack_message(slack_msg, 'slack_failure_alert')

    def get_slack_mentions(self):

        responsible = ','.join(['<@'+str(id)+'>' for id in self.slack_ids])
        return responsible