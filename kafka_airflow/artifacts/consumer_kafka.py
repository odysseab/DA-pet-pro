# consumer_kafka.py
import json
import psycopg2
from confluent_kafka import Consumer, KafkaError
import datetime
import re
import logging

logging.basicConfig(level=logging.INFO)

PG_CONFIG = {
    'host': '172.17.1.76',
    'port': 5432,
    'dbname': 'kafka_task',
    'user': 'lab_user',
    'password': 'lab_pass'
}

KAFKA_BROKER = '172.17.1.76:9092'
TOPIC = 'task_events_log_yudin'
GROUP_ID = 'consumer_group_yudin'

def validate_and_transform(rec):
    """
    Возвращает кортеж (user_name, email, age, site_action, event_date) или None,
    если запись не проходит валидацию.
    """
    # user_name
    user_name = rec.get('user_name')
    if user_name is None or not isinstance(user_name, str):
        return None
    stripped = user_name.strip()
    if stripped == '' or len(stripped) >= 100:
        return None
    user_name = ' '.join(word.capitalize() for word in stripped.split())

    # email
    email = rec.get('email')
    if email is not None and isinstance(email, str):
        email = email.strip().lower()
        # простая проверка формата (можно улучшить)
        if not re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', email):
            email = None
    else:
        email = None

    # age
    age = rec.get('age')
    try:
        age_int = int(age)
    except (ValueError, TypeError):
        age_int = 0
    if not (1 <= age_int <= 100):
        age_int = 0

    # site_action
    site_action = rec.get('site_action')
    if site_action is None or not isinstance(site_action, str):
        return None
    site_action = site_action.strip().lower()
    if site_action not in ('login', 'logout', 'view', 'click', 'purchase'):
        return None

    # event_date
    event_date_str = rec.get('event_date')
    if not event_date_str:
        return None
    # пробуем разные форматы
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M:%S.%f'):
        try:
            event_date = datetime.datetime.strptime(event_date_str, fmt)
            break
        except ValueError:
            continue
    else:
        return None

    return (user_name, email, age_int, site_action, event_date)

def insert_record(conn, record):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO kafka_task.kafka_dev.events_log_yudin
                (user_name, email, age, site_action, event_date)
            VALUES (%s, %s, %s, %s, %s)
        """, record)
        conn.commit()

def main():
    consumer = Consumer({
        'bootstrap.servers': KAFKA_BROKER,
        'group.id': GROUP_ID,
        'auto.offset.reset': 'earliest',
        'enable.auto.commit': False
    })
    consumer.subscribe([TOPIC])

    conn = psycopg2.connect(**PG_CONFIG)

    try:
        while True:
            msg = consumer.poll(timeout=1.0)  # таймаут для возможности остановки
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                else:
                    logging.error(f'Consumer error: {msg.error()}')
                    break

            try:
                payload = json.loads(msg.value().decode('utf-8'))
                transformed = validate_and_transform(payload)
                if transformed is not None:
                    insert_record(conn, transformed)
                    logging.info(f'Inserted record id {payload.get("id")}')
                else:
                    logging.warning(f'Invalid record skipped: {payload}')
            except Exception as e:
                logging.error(f'Processing error: {e}')

            # Фиксируем смещение после успешной обработки
            consumer.commit(msg)

    except KeyboardInterrupt:
        pass
    finally:
        consumer.close()
        conn.close()

if __name__ == '__main__':
    main()