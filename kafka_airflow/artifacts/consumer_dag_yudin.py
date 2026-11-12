# consumer_dag.py
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
    'kafka_consumer_yudin',
    default_args=default_args,
    description='Consume and validate Kafka messages into target table',
    schedule_interval='0 19 * * *',
    catchup=False,
)

# def run_consumer():
#     subprocess.run(['python3', '/path/to/consumer_kafka.py'], check=True)

# task = PythonOperator(
#     task_id='run_kafka_consumer',
#     python_callable=run_consumer,
#     dag=dag,

run_producer = BashOperator(
    task_id='run_kafka_consumer',
    bash_command='python3 /opt/airflow/dags/s_yudin/consumer_kafka.py',
    dag=dag,

)