-------------- Задание 1 - DISTRIBUTION -------------------

--select count(*) from public.yndx_logs_ext yle where extract(year from date) = 2025;

-- min 2022-09-08
-- max 2026-06-15
-- 1153221 записей для 2025 года - партиции по месяцу

-- Создаём схему и затем оптимальную таблицу в схеме
create table s_yudin.yndx_metrica_logs_opt (
    date date,
    dt timestamp,
    visitid text,
    isnewuser bigint,
    starturl text,
    endurl text,
    pageviews bigint,
    visitduration bigint,
    regioncountry text,
    regioncity text,
    clientid text,
    ipaddress text,
    clienttimezone bigint,
    devicecategory bigint,
    mobilephone text,
    mobilephonemodel text,
    operatingsystem text,
    browser text
)
with (
	appendonly = true,
	orientation = column,
	compresstype = zlib,
	compresslevel = 5
)
distributed by (ipaddress)
partition by range (date)
(
    partition p_month start (date '2022-08-01') end (date '2026-08-01') every (interval '1 month')
);



--Загрузка данных из внешней таблицы

INSERT INTO s_yudin.yndx_metrica_logs_opt
SELECT * FROM public.yndx_logs_ext;


--Оценка перекоса данных (skew)

--SELECT gp_segment_id, count(*) FROM <student_schema>.yndx_metrica_logs_opt GROUP BY 1;

-- Количество строк на каждом сегменте
SELECT gp_segment_id, count(*) AS rows
FROM s_yudin.yndx_metrica_logs_opt
GROUP BY gp_segment_id;

--gp_segment_id	"rows"
--0	2834932
-- один сегмент - проверка бессмысленна

-- Коэффициент перекоса (значение > 1.2–1.5 считается проблемой)
--SELECT skcoid, skcnamespace, skcrelname, skccoeff
--FROM gp_toolkit.gp_skew_coefficients
--WHERE skcrelname = 'yndx_metrica_logs_opt';


-------------- Задание 2 - EXCHANGE PARTITION ------------ 

--Шаг 1. Определить последнюю партицию
-- yndx_metrica_logs_opt_1_prt_p_month_48

-- Получить имя и границы последней партиции (по максимальному START)
SELECT 
    partitiontablename AS partition_name,
    partitionrangestart,
    partitionrangeend
FROM pg_partitions
WHERE schemaname = 's_yudin'
  AND tablename = 'yndx_metrica_logs_opt'
  AND partitionrangestart IS NOT NULL
ORDER BY partitionrangestart DESC
LIMIT 1;
--result:
-- yndx_metrica_logs_opt_1_prt_p_month_48	'2026-07-01'::date	'2026-08-01'::date

--Шаг 2. Создать staging-таблицу (без партиций)
--одинаковая структура с основной

CREATE TABLE s_yudin.stg_yndx_metrica_logs_opt
(LIKE s_yudin.yndx_metrica_logs_opt INCLUDING DEFAULTS INCLUDING STORAGE)
DISTRIBUTED BY (ipaddress);

--Шаг 3. Выгрузить данные из последней партиции в staging

INSERT INTO s_yudin.stg_yndx_metrica_logs_opt
SELECT * FROM s_yudin.yndx_metrica_logs_opt_1_prt_p_month_48;

select * from s_yudin.stg_yndx_metrica_logs_opt;

--т.к. послденяя партиция пустая - возьмем предыдущую
SELECT * FROM s_yudin.yndx_metrica_logs_opt_1_prt_p_month_47;

--удалим 48
--определим ключ партиции
SELECT partitiontablename, partitionname, partitiontype, partitionboundary
FROM pg_catalog.pg_partitions
WHERE schemaname = 's_yudin' 
  AND tablename = 'yndx_metrica_logs_opt'
  AND partitionname = 'p_month_48';

--partitionboundary:
--PARTITION p_month_48 START ('2026-07-01'::date) END ('2026-08-01'::date) 
--EVERY ('1 mon'::interval) 
--WITH (appendonly='true', orientation='column', compresstype=zlib, compresslevel='5') 

--ключ партици : '2026-07-01'
ALTER TABLE s_yudin.yndx_metrica_logs_opt DROP PARTITION for ('2026-07-01');

--выгрузим данные из 47 партиции
INSERT INTO s_yudin.stg_yndx_metrica_logs_opt
SELECT * FROM s_yudin.yndx_metrica_logs_opt_1_prt_p_month_47;

--изменим ключ партиционирования - для этого обновим дату, увеличив на 1 месяц

UPDATE s_yudin.stg_yndx_metrica_logs_opt
SET date = date + INTERVAL '1 month';

--создадим новую партицию )
ALTER TABLE s_yudin.yndx_metrica_logs_opt
ADD PARTITION p_month_48 START (DATE '2026-07-01') END (DATE '2026-08-01')
WITH (appendonly=true, orientation=column, compresstype=zlib, compresslevel=5);

--Direct Partition Exchange
ALTER TABLE s_yudin.yndx_metrica_logs_opt
EXCHANGE PARTITION p_month_48
WITH TABLE s_yudin.stg_yndx_metrica_logs_opt
WITHOUT VALIDATION;   -- для ускорения, но безопаснее с проверкой

--проверим
SELECT * FROM s_yudin.yndx_metrica_logs_opt_1_prt_p_month_48;

SELECT * FROM s_yudin.stg_yndx_metrica_logs_opt; -- пустая

