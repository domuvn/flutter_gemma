#!/bin/bash

# Script to split large model files into parts for Android asset bundling
# Android has a 2GB limit per asset file
#
# Usage: ./split_model.sh <model_file> [chunk_size_mb]
#
# Example: ./split_model.sh gemma-7b-it.bin 1900

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <model_file> [chunk_size_mb]"
    echo ""
    echo "Example: $0 gemma-7b-it.bin 1900"
    echo ""
    echo "Default chunk size: 1900 MB (safe for Android 2GB limit)"
    exit 1
fi

MODEL_FILE="$1"
CHUNK_SIZE_MB="${2:-1900}"  # Default 1900 MB to stay under 2GB limit

if [ ! -f "$MODEL_FILE" ]; then
    echo "Error: File '$MODEL_FILE' not found"
    exit 1
fi

# Get file size in MB
FILE_SIZE_MB=$(du -m "$MODEL_FILE" | cut -f1)

echo "Model file: $MODEL_FILE"
echo "File size: ${FILE_SIZE_MB} MB"
echo "Chunk size: ${CHUNK_SIZE_MB} MB"
echo ""

if [ "$FILE_SIZE_MB" -le "$CHUNK_SIZE_MB" ]; then
    echo "File is smaller than chunk size. No splitting needed."
    exit 0
fi

# Calculate number of parts
NUM_PARTS=$(( ($FILE_SIZE_MB + $CHUNK_SIZE_MB - 1) / $CHUNK_SIZE_MB ))
echo "Will create $NUM_PARTS parts..."
echo ""

# Split the file
# Using bs=1M for 1MB blocks
split -b ${CHUNK_SIZE_MB}M "$MODEL_FILE" "${MODEL_FILE}.part"

# Rename parts to .part1, .part2, etc.
PART_NUM=1
for file in "${MODEL_FILE}.part"*; do
    if [ -f "$file" ]; then
        mv "$file" "${MODEL_FILE}.part${PART_NUM}"
        SIZE=$(du -h "${MODEL_FILE}.part${PART_NUM}" | cut -f1)
        echo "Created: ${MODEL_FILE}.part${PART_NUM} (${SIZE})"
        PART_NUM=$((PART_NUM + 1))
    fi
done

echo ""
echo "✓ Successfully split $MODEL_FILE into $NUM_PARTS parts"
echo ""
echo "Next steps:"
echo "1. Add all parts to your Flutter assets in pubspec.yaml:"
echo "   flutter:"
echo "     assets:"
for i in $(seq 1 $NUM_PARTS); do
    echo "       - assets/models/${MODEL_FILE}.part${i}"
done
echo ""
echo "2. Use the base filename in your code:"
echo "   InferenceModelSpec("
echo "     name: 'model',"
echo "     modelUrl: 'asset://assets/models/${MODEL_FILE}',"
echo "   )"
echo ""
echo "The installer will auto-detect and assemble the parts."