def check_task_status(previous_task, **context):
    dag_run = context['dag_run']
    previous_ti =  dag_run.get_task_instance(previous_task)
    print(f"{previous_ti} is previous task status")
    
    if previous_ti.state in  ['failed', 'upstream']: 
        return 'repair_task'
    return 'end'