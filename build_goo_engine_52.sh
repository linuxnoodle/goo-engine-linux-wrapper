#!/bin/bash
# ============================================================================
# Goo Engine 5.2 Linux Build Script  (goo-engine-linux-wrapper, v5.2-beta)
#
# Builds the NaMgAl-Studio/goo-engine-5.2.0 port (Goo Engine NPR feature set
# re-implemented on Blender 5.2 / EEVEE-Next) with:
#   - the wrapper's v4.4-era library patches
#   - a dedicated "Goo Engine" render engine entry (BLENDER_GOO_ENGINE)
#   - the dependency-cycle fix that makes legacy Goo shader packs render
#     (black-material bug)
#   - HIP (AMD ROCm) Cycles support
#
# Differences vs. the v4.4 build script are documented in DIFFERENCES_52.md.
# ============================================================================
set -e

REPO_URL="https://github.com/NaMgAl-Studio/goo-engine-5.2.0.git"
GOO_ENGINE_BRANCH="main"

WRAPPER_DIR=$(pwd)
SOURCE_DIR="$WRAPPER_DIR/goo-engine"
LIB_DIR="$SOURCE_DIR/lib/linux_x64"
DIFF_REF_DIR="$WRAPPER_DIR/diff_ref"
LOCATIONS_FILE="$DIFF_REF_DIR/_file_locations.txt"

# Cycles HIP kernels for AMD (6950 XT = gfx1030). Add more archs as needed,
# e.g. "-DCYCLES_HIP_BINARIES_ARCH=gfx1030;gfx1100". Leave empty to build
# CPU-only Cycles.
HIP_ARCH="gfx1030"

BUILD_CMAKE_ARGS="-DWITH_ASSERT_ABORT=OFF -DWITH_GPU_SHADER_CPP_COMPILATION=OFF"
if [ -n "$HIP_ARCH" ]; then
    BUILD_CMAKE_ARGS="$BUILD_CMAKE_ARGS -DWITH_CYCLES_DEVICE_HIP=ON -DWITH_CYCLES_HIP_BINARIES=ON -DCYCLES_HIP_BINARIES_ARCH=$HIP_ARCH"
fi

echo "=== Starting Goo Engine 5.2 Build Process ==="

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
                (cd "$SOURCE_DIR" && GIT_LFS_SKIP_SMUDGE=1 git checkout -f "$git_rel_path" 2>/dev/null || true)
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
                echo "     - Patch:  $patch_file"
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
    GIT_LFS_SKIP_SMUDGE=1 git clone "$REPO_URL" goo-engine
fi

cd goo-engine
GIT_LFS_SKIP_SMUDGE=1 git checkout -f "$GOO_ENGINE_BRANCH"

echo "Installing Linux system packages..."
python3 build_files/build_environment/install_linux_packages.py || true

echo "Downloading precompiled libraries (git LFS submodule)..."
python3 build_files/utils/make_update.py --use-linux-libraries

echo "Applying patches from manifest..."

while read -r name rel_path; do
    [[ "$name" =~ ^#.*$ ]] && continue
    [ -z "$name" ] && continue

    apply_patch_from_manifest "$name"

done < "$LOCATIONS_FILE"

echo "Applying bl_ui panel-compatibility patch (Goo Engine settings panels)..."
python3 "$WRAPPER_DIR/patch_bl_ui_52.py" "$SOURCE_DIR/scripts/startup/bl_ui"

# --- startup.blend / datafiles handling -------------------------------------
# The 5.2 port pulls real binaries through git LFS, so the v4.4 fallback files
# are normally NOT needed. Kept for parity in case an LFS pointer leaks through.
STARTUP_BLEND="$SOURCE_DIR/release/datafiles/startup.blend"
if [ -f "$STARTUP_BLEND" ] && file "$STARTUP_BLEND" | grep -q "ASCII\|text"; then
    echo "startup.blend is an LFS pointer, using fallback_startup.blend..."
    cp "$WRAPPER_DIR/fallback_startup.blend" "$STARTUP_BLEND"
fi

echo "Starting Compilation (make)..."
# NOTE: unlike v4.4, 5.2 keeps lib/linux_x64/webp named "webp" (the 5.2 CMake
# expects ${LIBDIR}/webp; the v4.4 webp->libwebp rename must NOT be applied).
cd "$SOURCE_DIR"
make BUILD_CMAKE_ARGS="$BUILD_CMAKE_ARGS" -j$(nproc)

BUILD_LIB_DIR="$WRAPPER_DIR/build_linux/bin/lib"
SYCL_SRC="$LIB_DIR/dpcpp/lib"
if [ -d "$BUILD_LIB_DIR" ] && [ -d "$SYCL_SRC" ]; then
    echo "Copying SYCL runtime libraries (same runtime fix as v4.4)..."
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
echo "Install with: bash install_goo_engine_52.sh"
