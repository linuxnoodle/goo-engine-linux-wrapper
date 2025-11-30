#!/bin/bash
set -e

# Reference variables
REPO_URL="https://github.com/dillongoostudios/goo-engine.git"
WRAPPER_DIR=$(pwd)

# This might change depending on future lib values, change if needed
SOURCE_DIR="$WRAPPER_DIR/goo-engine"
LIB_DIR="$SOURCE_DIR/lib/linux_x64"
DIFF_REF_DIR="$WRAPPER_DIR/diff_ref"
LOCATIONS_FILE="$DIFF_REF_DIR/_file_locations.txt"

echo "=== Starting Goo Engine Build Process ==="

# Usage: apply_patch_from_manifest "filename"
apply_patch_from_manifest() {
    local search_name="$1"
    
    if [ ! -f "$LOCATIONS_FILE" ]; then
        echo "Error: _file_locations.txt not found in diff_ref!"
        return 1
    fi

    # Read the file line by line to find the matching filename
    local found=0
    while read -r name rel_path; do
        # Skip comments or empty lines
        [[ "$name" =~ ^#.*$ ]] && continue
        [ -z "$name" ] && continue

        if [ "$name" == "$search_name" ]; then
            found=1
            local target_path="$WRAPPER_DIR/$rel_path"
            local patch_file="$DIFF_REF_DIR/$name.patch"
            local to_file="$DIFF_REF_DIR/$name.to"

            # 1. Check if target exists
            if [ ! -f "$target_path" ]; then
                echo "  [SKIPPING] $name: Target file not found at $target_path"
                return 0
            fi

            # 2. Git Reset (Safety check for tracked files)
            if [[ "$target_path" == *"/goo-engine/"* ]]; then
                local git_rel_path="${target_path#$SOURCE_DIR/}"
                (cd "$SOURCE_DIR" && git checkout "$git_rel_path" 2>/dev/null || true)
            fi

            # 3. Check if Patch File exists
            if [ ! -f "$patch_file" ]; then
                echo "  [ERROR] $name: Patch file missing at $patch_file"
                return 0
            fi

            # 4. Idempotency Check
            if [ -f "$to_file" ] && cmp -s "$target_path" "$to_file"; then
                echo "  [INFO] $name: Patch already applied (Matches reference). Skipping."
                return 0
            fi

            # 5. Dry Run Check & User Prompt
            if patch -N --dry-run --silent "$target_path" "$patch_file" &>/dev/null; then
                echo "  [APPLYING] Patching $name..."
                patch -N "$target_path" "$patch_file"
            else
                echo "  [WARNING] $name: Patch does NOT apply cleanly."
                echo "     - Target: $target_path"
                echo "     - Patch: $patch_file"
                echo "     - Reason: The target file may have changed upstream, or the patch is malformed."
                
                # Prompt user (Explicitly read from /dev/tty to avoid reading the file loop)
                read -r -p "  [PROMPT] Do you want to continue the build anyway? [y/N] " response < /dev/tty
                
                # Default to 'n' if empty or not 'y'
                if [[ ! "$response" =~ ^[yY]$ ]]; then
                    echo "  [ABORT] User cancelled build."
                    exit 1
                fi
                
                echo "  [INFO] Skipping failed patch and continuing..."
            fi
            
            break # Stop reading after match
        fi
    done < "$LOCATIONS_FILE"

    if [ $found -eq 0 ]; then
        echo "  [WARNING] $search_name not defined in _file_locations.txt"
    fi
}

# Clone
if [ -d "goo-engine" ]; then
    echo "Directory goo-engine exists. Skipping initial clone..."
else
    git clone "$REPO_URL" goo-engine
fi

cd goo-engine
git checkout -b goo-engine-v4.3-release

echo "Installing Linux system packages..."
python build_files/build_environment/install_linux_packages.py

# Regenerate the patch files just in case.
if [ -f "$WRAPPER_DIR/generate_patches.sh" ]; then
    chmod +x "$WRAPPER_DIR/generate_patches.sh"
    "$WRAPPER_DIR/generate_patches.sh"
fi

echo "Downloading precompiled libraries..."
python build_files/utils/make_update.py --use-linux-libraries

echo "Renaming webp folder in libraries..."
if [ -d "$LIB_DIR/webp" ]; then
    if [ -d "$LIB_DIR/libwebp" ]; then
        rm -rf "$LIB_DIR/libwebp"
    fi
    mv "$LIB_DIR/webp" "$LIB_DIR/libwebp"
fi

# Apply Patches
echo "Applying remaining patches from manifest..."

while read -r name rel_path; do
    [[ "$name" =~ ^#.*$ ]] && continue
    [ -z "$name" ] && continue

    if [ "$name" == "make_update.py" ]; then
        continue
    fi
    
    apply_patch_from_manifest "$name"

done < "$LOCATIONS_FILE"

# Compile
echo "Starting Compilation (make)..."
cd "$SOURCE_DIR"
make -j$(nproc)

echo "=== Build Complete ==="
