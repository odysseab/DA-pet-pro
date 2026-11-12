

--Создание целевой таблицы

CREATE TABLE IF NOT EXISTS kafka_task.kafka_dev.events_log_yudin (
    id           BIGSERIAL PRIMARY KEY,
    user_name    VARCHAR(100),
    email        VARCHAR(254),
    age          SMALLINT,
    site_action  VARCHAR(20),
    event_date   TIMESTAMP,
    load_dttm    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


--создадим таблицу для харнения последнего обработанного id для нашего источника

CREATE TABLE IF NOT EXISTS kafka_task.kafka_dev.producer_offset_yudin (
	table_name TEXT PRIMARY KEY,
	last_id BIGINT
);

--SELECT last_id FROM kafka_task.kafka_dev.producer_offset_yudin
--            WHERE table_name = 'events_source';

--TRUNCATE TABLE kafka_task.kafka_dev.producer_offset_yudin;
--
--
--select * from kafka_task.kafka_prod.events_source es ;





