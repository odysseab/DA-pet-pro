#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory_with_csv>"
    exit 1
fi

input_dir="$1"
output_base="partitions"

mkdir -p "$output_base"

for csv_file in "$input_dir"/*.csv; do
    [ -f "$csv_file" ] || continue
    base=$(basename "$csv_file" .csv)
    stock_dir="$output_base/$base"
    mkdir -p "$stock_dir"

    header=$(head -n 1 "$csv_file")
    echo "$header" > "$stock_dir/header.csv"

    awk -v stock_dir="$stock_dir" -F ',' '
    NR > 1 {
        date = $1
        gsub(/"/, "", date)
        split(date, parts, "-")
        if (length(parts[1]) == 4 && length(parts[2]) == 2) {
            month = parts[1] "-" parts[2]
            cmd = "mkdir -p " stock_dir "/" month
            system(cmd)
            print >> (stock_dir "/" month "/data.csv")
        }
    }
    ' "$csv_file"
done