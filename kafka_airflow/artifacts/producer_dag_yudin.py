# producer_dag.py
from airflow import DAG
# from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta
import subprocess

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2026, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'kafka_producer_yudin',
    default_args=default_args,
    description='Send new rows from events_source to Kafka',
    schedule_interval='0 8 * * *',
    catchup=False,
)

# def run_producer():
#     # Убедитесь, что путь к скрипту правильный
#     subprocess.run(['python3', '/opt/airflow/dags/s_yudin/produccer_kafka.py'], check=True)

run_producer = BashOperator(
    task_id='run_kafka_producer',
    bash_command='python3 /opt/airflow/dags/s_yudin/producer_kafka.py',
    dag=dag,
)