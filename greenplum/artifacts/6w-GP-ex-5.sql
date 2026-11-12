-- Внешняя таблица для сделок
DROP EXTERNAL TABLE IF EXISTS s_yudin.moex_trades_ext;

CREATE EXTERNAL TABLE s_yudin.moex_trades_ext (
    TRADENO bigint,
    TRADETIME text,
    BOARDID text,
    SECID text,
    PRICE double precision,
    QUANTITY bigint,
    VALUE double precision,
    PERIOD text,
    TRADETIME_GRP bigint,
    SYSTIME text,
    BUYSELL text,
    DECIMALS bigint,
    TRADINGSESSION text,
    TRADEDATE text,
    TRADE_SESSION_DATE text
)
LOCATION ('pxf:///data/raw/s_yudin/moex/YDEX_2026-06-17.parquet?PROFILE=hdfs:parquet')
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_import');

--Создание внутренней оптимизированной витрины
select * from s_yudin.moex_trades_ext;
select min(TRADETIME::time), max(TRADETIME::time) from s_yudin.moex_trades_ext;
--2026-06-17	2026-06-17

--витрина
CREATE TABLE s_yudin.moex_mart (
    BOARDID text,
    BOARD_NAME text,
    ISIN text,
    ISQUALIFIEDINVESTORS boolean,
    SECID text,
    PRICE numeric(18,6),
    VALUE numeric(20,2),
    QUANTITY bigint,
    DEAL_TYPE text,
    DEAL_TIME time,
    TRADE_SESSION_DATE date
)
WITH (appendonly=true, orientation=column, compresstype=zlib, compresslevel=5)
DISTRIBUTED BY (SECID);


--заполнение данных
INSERT INTO s_yudin.moex_mart (BOARDID, SECID, PRICE, VALUE, QUANTITY, DEAL_TYPE, DEAL_TIME, TRADE_SESSION_DATE)
SELECT
    BOARDID,
    SECID,
    PRICE::numeric(18,6),
    VALUE::numeric(20,2),
    QUANTITY,
    CASE WHEN BUYSELL = 'B' THEN 'BUY' ELSE 'SELL' END,
    TRADETIME::time,
    TRADEDATE::date
FROM s_yudin.moex_trades_ext;

--проверка
SELECT COUNT(*) FROM s_yudin.moex_mart;
SELECT * FROM s_yudin.moex_mart LIMIT 10;

--найдем максимальную сделку по сумме (VALUE) для каждого типа (BUY/SELL):
WITH ranked AS (
    SELECT
        SECID,
        DEAL_TYPE,
        TRADE_SESSION_DATE,
        VALUE,
        PRICE,
        QUANTITY,
        DEAL_TIME,
        BOARDID,
        BOARD_NAME,
        ISIN,
        ISQUALIFIEDINVESTORS,
        ROW_NUMBER() OVER (PARTITION BY DEAL_TYPE ORDER BY VALUE DESC) AS rn
    FROM s_yudin.moex_mart
--    WHERE SECID = 'YDEX'
--      AND TRADE_SESSION_DATE = '2026-06-17'
)
SELECT
    SECID,
    DEAL_TYPE,
    TRADE_SESSION_DATE,
    VALUE AS largest_values,
    PRICE,
    QUANTITY,
    DEAL_TIME,
    BOARDID,
    BOARD_NAME,
    ISIN,
    ISQUALIFIEDINVESTORS
FROM ranked
WHERE rn <= 5
ORDER BY DEAL_TYPE;





