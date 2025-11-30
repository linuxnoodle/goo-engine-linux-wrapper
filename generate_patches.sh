#!/bin/bash
set -e

WRAPPER_DIR=$(pwd)
DIFF_REF_DIR="$WRAPPER_DIR/diff_ref"

echo "=== Generating Patches ==="

if [ ! -d "$DIFF_REF_DIR" ]; then
    echo "Warning: diff_ref directory not found at $DIFF_REF_DIR"
    exit 0
fi

# Iterate over all .to files
for to_file in "$DIFF_REF_DIR"/*.to; do
    # Check if file exists to handle empty directory case
    [ -e "$to_file" ] || continue

    filename=$(basename "$to_file" .to)
    from_file="$DIFF_REF_DIR/$filename.from"
    patch_file="$DIFF_REF_DIR/$filename.patch"

    if [ ! -f "$from_file" ]; then
        echo "Skipping $filename (Missing .from file)"
        continue
    fi

    echo "Generating patch for $filename..."
    # Generate patch (ignore exit code 1 which means diffs found)
    diff -u "$from_file" "$to_file" > "$patch_file" || true
done

echo "=== Patch Generation Complete ==="
