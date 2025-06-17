#!/bin/bash

set -e

# Check arguments
if [ $# -ne 3 ]; then
  echo "Usage: $0 input.mkv start_time end_time"
  echo "Example: $0 input.mkv 01:00:23 01:00:37"
  exit 1
else
  echo "Processing..."
fi

INPUT="$1"
START="$2"
END="$3"
PART1="__part1.mkv"
PART2="__part2.mkv"
CONCAT_LIST="__concat_list.txt"
OUTPUT="output.mkv"

# Cleanup any leftover temp files
rm -f "$PART1" "$PART2" "$CONCAT_LIST"

# Extract parts before and after the segment to be removed
ffmpeg -hide_banner -loglevel error -i "$INPUT" -ss 00:00:00 -to "$START" -c copy "$PART1"
ffmpeg -hide_banner -loglevel error -i "$INPUT" -ss "$END" -c copy "$PART2"

# Create concat list
echo "file '$PART1'" > "$CONCAT_LIST"
echo "file '$PART2'" >> "$CONCAT_LIST"

# Merge the parts
ffmpeg -hide_banner -loglevel error -f concat -safe 0 -i "$CONCAT_LIST" -c copy "$OUTPUT"

# Cleanup
rm -f "$PART1" "$PART2" "$CONCAT_LIST"

echo "✅ Done! Output saved to $OUTPUT"
