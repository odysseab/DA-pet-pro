CREATE SCHEMA IF NOT EXISTS s_yudin;


CREATE TABLE IF NOT EXISTS s_yudin.stock_prices_YDEX (
    ticket VARCHAR(10) NOT NULL,
    sector VARCHAR(50) NOT NULL,
    begin TIMESTAMP NOT NULL,
    open NUMERIC(12,4),
    low NUMERIC(12,4),
    high NUMERIC(12,4),
    close NUMERIC(12,4),
    volume NUMERIC(15,0),
    CONSTRAINT pk_YDEX PRIMARY KEY (ticket, begin)
);

CREATE TABLE IF NOT EXISTS s_yudin.stock_prices_SBER (
    ticket VARCHAR(10) NOT NULL,
    sector VARCHAR(50) NOT NULL,
    begin TIMESTAMP NOT NULL,
    open NUMERIC(12,4),
    low NUMERIC(12,4),
    high NUMERIC(12,4),
    close NUMERIC(12,4),
    volume NUMERIC(15,0),
    CONSTRAINT pk_SBER PRIMARY KEY (ticket, begin)
);

CREATE TABLE IF NOT EXISTS s_yudin.stock_prices_GAZP (
    ticket VARCHAR(10) NOT NULL,
    sector VARCHAR(50) NOT NULL,
    begin TIMESTAMP NOT NULL,
    open NUMERIC(12,4),
    low NUMERIC(12,4),
    high NUMERIC(12,4),
    close NUMERIC(12,4),
    volume NUMERIC(15,0),
    CONSTRAINT pk_GAZP PRIMARY KEY (ticket, begin)
);
    
CREATE TABLE IF NOT EXISTS s_yudin.stock_prices_GCHE (
    ticket VARCHAR(10) NOT NULL,
    sector VARCHAR(50) NOT NULL,
    begin TIMESTAMP NOT NULL,
    open NUMERIC(12,4),
    low NUMERIC(12,4),
    high NUMERIC(12,4),
    close NUMERIC(12,4),
    volume NUMERIC(15,0),
    CONSTRAINT pk_GCHE PRIMARY KEY (ticket, begin)
);

