from airflow.operators.bash import BashOperator
from airflow.exceptions import AirflowException
from datetime import datetime, timedelta
import os
import json
import logging

class DBTOperator(BashOperator):
    """Custom operator para ejecutar comandos DBT con capacidad de recuperación y taggeo"""
    
    template_fields = ('bash_command', 'env')

    def __init__(
        self,
        #model: str,
        tags: list, 
        dbt_command: str = 'run',
        full_refresh: bool = False,
        *args, **kwargs
    ):
        #self.tags = model
        self.tags = tags
        self.dbt_command = dbt_command
        self.full_refresh = full_refresh
        
        command = self._build_dbt_command()
        
        super().__init__(
            bash_command=command,
            *args, **kwargs
        )

    def _build_dbt_command(self) -> str:
        """Construye el comando DBT con los parámetros necesarios"""
        refresh_flag = '--full-refresh' if self.full_refresh else ''

        tag_flag = 'tag:'
        tag_flag += ',tag:'.join(self.tags)
        
        return f"""
            set -e;
            source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;
            cd /tmp/dbt/nubeproduct;
            dbt {self.dbt_command} --select {tag_flag} {refresh_flag} \
                --project-dir /tmp/dbt/nubeproduct \
                --profiles-dir .. \
                --state /tmp/dbt/state;
        """

    def execute(self, context):
        try:
            self._save_execution_state(context)
            super().execute(context)
            self._update_success_state(context)
            
        except Exception as e:
            self._save_error_state(context, str(e))
            raise AirflowException(f"Error en la ejecución de DBT para el modelo {self.tags}: {str(e)}")

    def _save_execution_state(self, context):
        """Guarda el estado de ejecución actual"""
        state = {
            'model': self.tags,
            'command': self.dbt_command,
            'timestamp': datetime.now().isoformat(),
            'task_id': context['task'].task_id,
            'task_group': context['task'].task_group.group_id if context['task'].task_group else None
        }
        
        os.makedirs('/tmp/dbt/state', exist_ok=True)
        state_file = f'/tmp/dbt/state/{self.tags}_current_state.json'
        with open(state_file, 'w') as f:
            json.dump(state, f)

    def _save_error_state(self, context, error_message):
        """Guarda información del error para recuperación"""
        error_state = {
            'error_message': error_message,
            'timestamp': datetime.now().isoformat(),
            'task_id': context['task'].task_id,
            'model': self.tags,
            'task_group': context['task'].task_group.group_id if context['task'].task_group else None
        }
        
        error_file = f'/tmp/dbt/state/{self.tags}_error_state.json'
        with open(error_file, 'w') as f:
            json.dump(error_state, f)

    def _update_success_state(self, context):
        """Actualiza el estado después de una ejecución exitosa"""
        success_state = {
            'last_successful_run': datetime.now().isoformat(),
            'model': self.tags,
            'task_id': context['task'].task_id,
            'task_group': context['task'].task_group.group_id if context['task'].task_group else None
        }
        
        success_file = f'/tmp/dbt/state/{self.tags}_success_state.json'
        with open(success_file, 'w') as f:
            json.dump(success_state, f)