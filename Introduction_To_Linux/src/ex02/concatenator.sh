#!/bin/bash

input_base="partitions"
output_base="rebuilt"

mkdir -p "$output_base"

for stock_dir in "$input_base"/*; do
    [ -d "$stock_dir" ] || continue
    stock=$(basename "$stock_dir")
    header_file="$stock_dir/header.csv"
    if [ ! -f "$header_file" ]; then
        echo "Warning: header.csv not found in $stock_dir, skipping"
        continue
    fi

    # Собираем все строки из всех data.csv
    tmp_file=$(mktemp)
    find "$stock_dir" -type f -name "data.csv" -exec cat {} \; > "$tmp_file"

    # Сортируем по дате (первое поле) в убывающем порядке
    sort -t ',' -k1,1r "$tmp_file" > "$tmp_file.sorted"

    # Формируем итоговый CSV с заголовком
    output_file="$output_base/${stock}.csv"
    cat "$header_file" > "$output_file"
    cat "$tmp_file.sorted" >> "$output_file"

    rm "$tmp_file" "$tmp_file.sorted"
    echo "Rebuilt $output_file"
done