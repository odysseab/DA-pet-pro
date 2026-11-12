#!/bin/bash

command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. Aborting." >&2; exit 1; }

if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory_with_json>"
    exit 1
fi

input_dir="$1"
output_dir="csv_data"

mkdir -p "$output_dir"

header="begin,open,low,high,close,volume"

for json_file in "$input_dir"/*.json; do
    [ -f "$json_file" ] || continue
    base=$(basename "$json_file" .json)
    output_file="$output_dir/${base}.csv"
    echo "$header" > "$output_file"
    jq -r -f filter.jq "$json_file" >> "$output_file"
    echo "Converted $json_file to $output_file"
done