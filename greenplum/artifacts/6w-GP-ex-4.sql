select * from countries c ;

CREATE EXTENSION IF NOT EXISTS pxf;
--extension "pxf" already exists, skipping

DROP EXTERNAL TABLE IF EXISTS s_yudin.countries_hdfs_ext_s;

CREATE WRITABLE EXTERNAL TABLE s_yudin.countries_hdfs_ext_s (
    id int,
    name text,
    iso_alpha2 text,
    iso_alpha3 text,
    iso_numeric int,
    cctld text,
    calling_code text,
    postal_format text
)
LOCATION ('pxf:///data/raw/s_yudin/countries?PROFILE=hdfs:parquet')
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_export')
DISTRIBUTED BY (id);

--наполняем
INSERT INTO s_yudin.countries_hdfs_ext_s
SELECT * FROM s_yudin.countries;

--проверим

-- Создаём читаемую внешнюю таблицу на те же данные

DROP EXTERNAL TABLE IF EXISTS s_yudin.countries_hdfs_read;

CREATE READABLE EXTERNAL TABLE s_yudin.countries_hdfs_read (
    id int,
    name text,
    iso_alpha2 text,
    iso_alpha3 text,
    iso_numeric int,
    cctld text,
    calling_code text,
    postal_format text
)
LOCATION ('pxf:///data/raw/countries?PROFILE=hdfs:parquet')
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_import');

-- Подсчёт записей
SELECT COUNT(*) FROM s_yudin.countries_hdfs_read;

