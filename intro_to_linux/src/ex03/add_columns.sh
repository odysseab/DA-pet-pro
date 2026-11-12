#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <rebuilt_directory>"
    exit 1
fi

input_dir="$1"
output_dir="with_columns"

if [ ! -d "$input_dir" ]; then
    echo "Error: Directory $input_dir does not exist."
    exit 1
fi

sectors_file=""
if [ -f "sectors.txt" ]; then
    sectors_file="sectors.txt"
elif [ -f "../ex00/sectors.txt" ]; then
    sectors_file="../ex00/sectors.txt"
else
    echo "Error: sectors.txt not found. Please place it in the current directory or in ../ex00/"
    exit 1
fi

declare -A sector_map
while IFS= read -r line; do
    # Пропускаем строки, не содержащие '|' или содержащие "Тикер"
    if [[ $line != *"|"* ]] || [[ $line == *"Тикер"* ]]; then
        continue
    fi
    # Извлекаем второе и третье поля, удаляем пробелы
    ticker=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    sector=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
    if [ -n "$ticker" ] && [ -n "$sector" ]; then
        sector_map["$ticker"]="$sector"
    fi
done < "$sectors_file"

if [ ${#sector_map[@]} -eq 0 ]; then
    echo "Warning: No entries found in sectors.txt. Please check the file format."
fi

mkdir -p "$output_dir"

for csv_file in "$input_dir"/*.csv; do
    [ -f "$csv_file" ] || continue
    base=$(basename "$csv_file" .csv)
    ticket="$base"
    sector="${sector_map[$ticket]}"
    if [ -z "$sector" ]; then
        echo "Warning: Sector not found for $ticket, using empty value."
        sector=""
    fi

    output_file="$output_dir/${base}.csv"
    {
        head -n 1 "$csv_file" | awk -v ticket="$ticket" -v sector="$sector" 'BEGIN{OFS=","} {print "TICKET,SECTOR," $0}'
        tail -n +2 "$csv_file" | while IFS= read -r line; do
            echo "$ticket,$sector,$line"
        done
    } > "$output_file"
    echo "Created $output_file"
done