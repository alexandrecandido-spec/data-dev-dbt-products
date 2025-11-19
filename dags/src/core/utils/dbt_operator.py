from airflow.operators.bash import BashOperator
from airflow.exceptions import AirflowException
from airflow.providers.slack.operators.slack_webhook import SlackWebhookOperator
from datetime import datetime
import os
import re
import json
import logging
from typing import Optional, Tuple, List
import subprocess
import boto3

class DBTOperator(BashOperator):
    """Custom operator para ejecutar comandos DBT con capacidad de recuperación y taggeo"""
    
    template_fields = ('bash_command', 'env', 'models')

    def __init__(
        self,
        tags: list, 
        dbt_command: str = 'run',
        full_refresh: bool = False,
        models: List[str] = None,
        retry: bool = False,
        *args, **kwargs
    ):
        
        self.dynamodb = boto3.resource("dynamodb",region_name="us-east-1")

        self.tags = tags
        self.dbt_command = dbt_command
        self.full_refresh = full_refresh
        self.models = models or []
        self.retry = retry
        self.project = "_".join(tags)

        command = self._build_dbt_command()
        self.repair_command = self._build_dbt_repair_command()
        
        super().__init__(
            bash_command=command,
            *args, **kwargs
        )

    def _build_dbt_command(self) -> str:
        """Construye el comando DBT con los parámetros necesarios"""
        refresh_flag = '--full-refresh' if self.full_refresh else ''
        
        # Si se indican modelos los ejecutara especificamente, de lo contrario ejecuta todos los modelos con tags especificadas
        if self.models and len(self.models) > 0:
            selection = ' '.join(self.models)
        else:
            selection = 'tag:'
            selection += ',tag:'.join(self.tags)
        
        execution = f"""
            set -e;
            source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;
            cd /tmp/dbt/{self.project}/nubeproduct;
            dbt deps;
            dbt {self.dbt_command} --select {selection} {refresh_flag} \
                --project-dir /tmp/dbt/{self.project}/nubeproduct \
                --profiles-dir /tmp/dbt;
        """
        logging.info(f"command executed: {execution}")
                
        return execution
    
    def _build_dbt_repair_command(self) -> str:
        """Construye la reparación del comando DBT con los parámetros necesarios, a ser ejecutada tras el error del comando principal"""

        tag_list = 'tag:'
        tag_list += ',tag:'.join(self.tags)
        
        execution = f'"result:error+,{tag_list}" --state /tmp/dbt/{self.project}/nubeproduct/target/'
        # "find /tmp/dbt -type f -name run_results.json"
        
        return f"""
            set -e;
            source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;
            cd /tmp/dbt/{self.project}/nubeproduct;
            dbt {self.dbt_command} --select {execution} \
                --project-dir /tmp/dbt/{self.project}/nubeproduct \
                --profiles-dir /tmp/dbt;
        """
        
    def _status_models_update(self):
        # Filtro jq que extrai do run_results.json, por modelo:
        # - status de execução
        # - nome do modelo (último segmento de unique_id)
        # - menor started_at (primeiro início entre os timings)
        # - maior completed_at do passo "execute" (término da execução)
        jq_run = r'''
            .results[]
            | select(.unique_id | startswith("model."))
            | [
                .status,
                (.unique_id | split(".")[-1]),
                ([.timing[]? | .started_at?] | min? // ""),
                ([.timing[]? | select(.name=="execute") | .completed_at?] | max? // "")
                ]
            | @tsv
            '''
        
        # Executa o jq contra o run_results.json do projeto e captura a saída como texto (TSV)
        res = subprocess.run(
            ["jq", "-r", jq_run, f"/tmp/dbt/{self.project}/nubeproduct/target/run_results.json"],
            check=True,
            capture_output=True,
            text=True
        )
        
        # Itera pelas linhas TSV retornadas (uma por modelo)
        for line in res.stdout.splitlines():
            status, model, started, finished = line.split("\t")
            model = f"model.nubeproduct.{model}"
            started_at = started.replace('Z', '')
            finished_at = finished.replace('Z', '')

            values = {}
            update_parts = ["started_at = :sa", "finished_at = :fa"]
            values[":sa"] = started_at
            values[":fa"] = finished_at
            
            # Se o status foi sucesso, também atualiza a coluna de término com sucesso
            if status == 'success':
                update_parts.append("success_finished_at = :sfa")
                values[":sfa"] = finished_at

            self._dynamo_update_table("dbt-processing-control", model, update_parts, values)
            

    def _dynamo_update_table(self, table: str, model: str, update_parts: Tuple[str], values: dict):
        
        #Atualiza um item no DynamoDB para o modelo informado.
        dynamo_table = self.dynamodb.Table(table)
        dynamo_table.update_item(
                Key={"model": model},
                UpdateExpression="SET " + ", ".join(update_parts),
                ExpressionAttributeValues=values
            )
        
    def _execute_bash_command(self, command: str) -> Tuple[bool, str]:
        """Ejecuta el comando bash y captura la salida en tiempo real"""
        process = subprocess.Popen(
            ['bash', '-c', command],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            bufsize=1
        )

        output_lines = []
        # Captura la salida en tiempo real
        while True:
            output = process.stdout.readline()
            if output:
                logging.info(output.strip())  # Imprime el progreso en tiempo real
                output_lines.append(output)
            if process.poll() is not None:
                break
            
        # Captura cualquier error restante
        stderr = process.stderr.read()
        if stderr:
            output_lines.append(stderr)

        success = process.returncode == 0

        if command == 'run':
            self._status_models_update()

        return success, ''.join(output_lines)

    def _parse_dbt_error(self, output: str) -> Optional[str]:
        """Extrae el mensaje de error específico de DBT"""
        if not output:
            return None
            
        lines = output.split('\n')
        error_message = []
        capturing = False
        
        for line in lines:
            # Busca el inicio del mensaje de error
            if 'ERROR' in line and 'creating' in line:
                capturing = True
                error_message = []
            # Captura detalles adicionales del error
            elif capturing and line.strip():
                if 'Done. PASS=' in line:  # Fin del mensaje de error
                    capturing = False
                    continue
                # Limpia códigos ANSI y agrega la línea
                clean_line = (line.replace('[0m', '')
                                .replace('[31m', '')
                                .strip())
                if clean_line and not clean_line.startswith('Running with dbt='):
                    error_message.append(clean_line)
        
        return '\n'.join(error_message) if error_message else None

    def _extract_test_fails(self, log):
        pattern1 = r"FAIL.*?\s+(dbt_expectations_.*?)\s+\[.*?FAIL"
        pattern2 = r"FAIL.*?\s+(not_null_.*?)\s+\[.*?FAIL"
        pattern3 = r"Failure in test\s+(\S+)"

        fails = re.findall(pattern1, log)
        fails += re.findall(pattern2, log)
        fails += re.findall(pattern3, log)

        return sorted(set(fails))  

    def execute(self, context):
        """Execute the bash command with real-time output and error handling"""
        try:
            # Update models from context if available and not already set
            if not self.models:
                dag_run_conf = context.get('dag_run').conf
                if dag_run_conf and 'models' in dag_run_conf:
                    self.models = dag_run_conf.get('models', [])
                    # Rebuild command with updated models
                    self.bash_command = self._build_dbt_command()
                    
            self._save_execution_state(context)
            
            # Execute main command
            success, output = self._execute_bash_command(self.bash_command)
            
            if self.dbt_command == 'test':
                if 'ERROR=' in output:
                    match = re.search(r'ERROR=(\d+)', output)
                    if match and int(match.group(1)) > 0:

                        error_msg = f"DBT test failures: {match.group(1)} tests failed.\n\n{output[:2000]}"  # truncate output if needed

                        context['task_instance'].xcom_push(
                            key='dbt_error_details',
                            value=error_msg
                        )

                        fails_list = self._extract_test_fails(error_msg)
                        formatted_fails = '\n'.join(fails_list) if fails_list else "No test names extracted."

                        SlackWebhookOperator(
                            task_id='slack_test_warning',
                            slack_webhook_conn_id='dbt_slack_alert',
                            message=f""":warning: *Test failures detected in `dbt test`*  
            *Task:* `{context['task_instance'].task_id}`  
            *Dag:* `{context['dag'].dag_id}`  
            *Execution Date:* {context['execution_date']}  
            *Log Url:* {context['task_instance'].log_url}  
            *Details:* ```{formatted_fails}```""",
                            channel="#dbt-alerts",
                        ).execute(context=context)

            if not success:
                # Si hay error, extrae y loguea el mensaje de error específico
                error_details = self._parse_dbt_error(output)
                
                # Intenta el comando de reparación
                logging.info("\n\nAttempting repair command execution...")
                repair_success, repair_output = self._execute_bash_command(self.repair_command)
                
                if not repair_success:
                    # Si la reparación falla, extrae el error
                    repair_error = self._parse_dbt_error(repair_output)
                    error_msg = f">>>> [!!!] Error en la ejecución de DBT para el modelo {self.tags}: >>>>>\n"
                    if error_details:
                        error_msg += f"\nOriginal error:\n{error_details}"
                    if repair_error:
                        error_msg += f"\nRepair error:\n{repair_error}"
                    
                    # Push error details to XCom
                    context['task_instance'].xcom_push(
                        key='dbt_error_details',
                        value= error_msg if error_msg else "Could not capture error."
                    )
                    raise AirflowException(error_msg)
                
            self._update_success_state(context)
            return output

        except Exception as e:
            if not isinstance(e, AirflowException):
                self._save_error_state(context, str(e))
                raise AirflowException(f"Error inesperado en DBT para el modelo {self.tags}: {str(e)}")
            raise AirflowException(str(e))

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