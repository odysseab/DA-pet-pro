# producer_kafka.py
import json
import psycopg2
from confluent_kafka import Producer
import datetime
import logging

logging.basicConfig(level=logging.INFO)

# Конфигурация PostgreSQL
PG_CONFIG = {
    'host': '172.17.1.76',
    'port': 5432,
    'dbname': 'kafka_task',
    'user': 'lab_user',
    'password': 'lab_pass'
}

# Конфигурация Kafka
KAFKA_BROKER = '172.17.1.76:9092'
TOPIC = 'task_events_log_yudin'



def get_last_processed_id(conn):
    with conn.cursor() as cur:
        # cur.execute("""
        #     CREATE TABLE IF NOT EXISTS kafka_task.kafka_dev.producer_offset (
        #         table_name TEXT PRIMARY KEY,
        #         last_id BIGINT
        #     );
        # """)
        # conn.commit()
        cur.execute("""
            SELECT last_id FROM kafka_task.kafka_dev.producer_offset_yudin
            WHERE table_name = 'events_source'
        """)
        row = cur.fetchone()
        return row[0] if row else 0

def update_last_processed_id(conn, last_id):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO kafka_task.kafka_dev.producer_offset_yudin (table_name, last_id)
            VALUES ('events_source', %s)
            ON CONFLICT (table_name) DO UPDATE SET last_id = EXCLUDED.last_id
        """, (last_id,))
        conn.commit()

def fetch_new_records(conn, last_id):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, user_name, email, age, site_action, event_date
            FROM kafka_task.kafka_prod.events_source
            WHERE id > %s
            ORDER BY id
        """, (last_id,))
        return cur.fetchall()

def delivery_report(err, msg):
    if err is not None:
        logging.error(f'Delivery failed: {err}')
    else:
        logging.info(f'Message delivered to {msg.topic()} [{msg.partition()}]')

def main():
    print("Hello apple!")

    conn = psycopg2.connect(**PG_CONFIG)


    try:
        last_id = get_last_processed_id(conn)
        print(f"Last processed ID: {last_id}")

        records = fetch_new_records(conn, last_id)
        print(f"Found {len(records)} new records")

        if not records:
            logging.info('No new records to send.')
            return

        producer = Producer({'bootstrap.servers': KAFKA_BROKER})

        max_id = last_id

        print("Run apple!")

        for rec in records:
            # rec: (id, user_name, email, age, site_action, event_date)
            # Преобразуем event_date в строку, если это datetime
            event_date_str = rec[5].isoformat() if isinstance(rec[5], datetime.datetime) else rec[5]
            payload = {
                'id': rec[0],
                'user_name': rec[1],
                'email': rec[2],
                'age': rec[3],
                'site_action': rec[4],
                'event_date': event_date_str
            }
            producer.produce(
                topic=TOPIC,
                key=str(rec[0]).encode(),
                value=json.dumps(payload).encode('utf-8'),
                callback=delivery_report
            )
            max_id = max(max_id, rec[0])

        producer.flush()
        # Обновляем смещение после успешной отправки всех сообщений
        update_last_processed_id(conn, max_id)
        logging.info(f'Processed records up to id {max_id}')
    finally:
        conn.close()

if __name__ == '__main__':
    main()