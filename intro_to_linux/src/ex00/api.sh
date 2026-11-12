#!/bin/bash

# Проверка наличия необходимых инструментов
command -v curl >/dev/null 2>&1 || { echo "curl is required but not installed. Aborting." >&2; exit 1; }
command -v jq >/dev/null 2>&1   || { echo "jq is required but not installed. Aborting." >&2; exit 1; }

# Создание папки для сырых данных (относительно текущей директории)
mkdir -p raw_data

# Диапазон дат: от 2010-01-01 до сегодняшнего дня
from_date="2010-01-01"
to_date=$(date +%Y-%m-%d)

# Обработка каждого переданного тикера
for ticker in "$@"; do
    echo "Fetching data for $ticker..."
    url="https://iss.moex.com/iss/engines/stock/markets/shares/securities/${ticker}/candles.json?from=${from_date}&till=${to_date}&interval=24"
    curl -s "$url" -o "raw_data/${ticker}.json"
    if [ $? -eq 0 ]; then
        echo "Saved raw_data/${ticker}.json"
    else
        echo "Error fetching data for $ticker" >&2
    fi
done