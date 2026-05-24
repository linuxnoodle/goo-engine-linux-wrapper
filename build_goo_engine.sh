#!/bin/bash
set -e

REPO_URL="https://github.com/dillongoostudios/goo-engine.git"
WRAPPER_DIR=$(pwd)
GOO_ENGINE_BRANCH="goo-engine-v4.4-release"

SOURCE_DIR="$WRAPPER_DIR/goo-engine"
LIB_DIR="$SOURCE_DIR/lib/linux_x64"
DIFF_REF_DIR="$WRAPPER_DIR/diff_ref"
LOCATIONS_FILE="$DIFF_REF_DIR/_file_locations.txt"

echo "=== Starting Goo Engine v4.4 Build Process ==="

apply_patch_from_manifest() {
    local search_name="$1"
    
    if [ ! -f "$LOCATIONS_FILE" ]; then
        echo "Error: _file_locations.txt not found in diff_ref!"
        return 1
    fi

    local found=0
    while read -r name rel_path; do
        [[ "$name" =~ ^#.*$ ]] && continue
        [ -z "$name" ] && continue

        if [ "$name" == "$search_name" ]; then
            found=1
            local target_path="$WRAPPER_DIR/$rel_path"
            local patch_file="$DIFF_REF_DIR/$name.patch"
            local to_file="$DIFF_REF_DIR/$name.to"

            if [ ! -f "$target_path" ]; then
                echo "  [SKIPPING] $name: Target file not found at $target_path"
                return 0
            fi

            if [[ "$target_path" == *"/goo-engine/"* ]]; then
                local git_rel_path="${target_path#$SOURCE_DIR/}"
                (cd "$SOURCE_DIR" && git checkout "$git_rel_path" 2>/dev/null || true)
            fi

            if [ ! -f "$patch_file" ]; then
                echo "  [ERROR] $name: Patch file missing at $patch_file"
                return 0
            fi

            if [ -f "$to_file" ] && cmp -s "$target_path" "$to_file"; then
                echo "  [INFO] $name: Patch already applied. Skipping."
                return 0
            fi

            if patch -N --dry-run --silent "$target_path" "$patch_file" &>/dev/null; then
                echo "  [APPLYING] Patching $name..."
                patch -N "$target_path" "$patch_file"
            else
                echo "  [WARNING] $name: Patch does NOT apply cleanly."
                echo "     - Target: $target_path"
                echo "     - Patch: $patch_file"
                
                read -r -p "  [PROMPT] Continue anyway? [y/N] " response < /dev/tty
                
                if [[ ! "$response" =~ ^[yY]$ ]]; then
                    echo "  [ABORT] User cancelled build."
                    exit 1
                fi
                
                echo "  [INFO] Skipping failed patch and continuing..."
            fi
            
            break
        fi
    done < "$LOCATIONS_FILE"

    if [ $found -eq 0 ]; then
        echo "  [WARNING] $search_name not defined in _file_locations.txt"
    fi
}

if [ -d "goo-engine" ]; then
    echo "Directory goo-engine exists. Skipping initial clone..."
else
    git clone "$REPO_URL" goo-engine
fi

cd goo-engine
git checkout "$GOO_ENGINE_BRANCH"

echo "Installing Linux system packages..."
python3 build_files/build_environment/install_linux_packages.py

if [ -f "$WRAPPER_DIR/generate_patches.sh" ]; then
    chmod +x "$WRAPPER_DIR/generate_patches.sh"
    "$WRAPPER_DIR/generate_patches.sh"
fi

echo "Downloading precompiled libraries..."
python3 build_files/utils/make_update.py --use-linux-libraries

echo "Renaming webp folder in libraries..."
if [ -d "$LIB_DIR/webp" ]; then
    if [ -d "$LIB_DIR/libwebp" ]; then
        rm -rf "$LIB_DIR/libwebp"
    fi
    mv "$LIB_DIR/webp" "$LIB_DIR/libwebp"
fi

echo "Applying patches from manifest..."

while read -r name rel_path; do
    [[ "$name" =~ ^#.*$ ]] && continue
    [ -z "$name" ] && continue
    
    apply_patch_from_manifest "$name"

done < "$LOCATIONS_FILE"

echo "Starting Compilation (make)..."
cd "$SOURCE_DIR"
make -j$(nproc)

BUILD_LIB_DIR="$WRAPPER_DIR/build_linux/bin/lib"
SYCL_SRC="$LIB_DIR/dpcpp/lib"
if [ -d "$BUILD_LIB_DIR" ] && [ -d "$SYCL_SRC" ]; then
    echo "Copying SYCL runtime libraries..."
    for f in libsycl.so libur_loader.so; do
        if [ -L "$SYCL_SRC/$f" ]; then
            SYCL_REAL=$(basename $(readlink "$SYCL_SRC/$f"))
            cp "$SYCL_SRC/$SYCL_REAL" "$BUILD_LIB_DIR/"
            cp "$SYCL_SRC/$f" "$BUILD_LIB_DIR/"
            ln -sf "$SYCL_REAL" "$BUILD_LIB_DIR/$f"
        fi
    done
fi

echo "=== Build Complete ==="
