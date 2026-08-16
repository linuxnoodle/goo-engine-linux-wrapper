#!/bin/bash
# ============================================================================
# Goo Engine 5.2 AppImage Build Script  (v5.2-beta branch)
#
# Bundles the 5.2 build output (build_linux/bin) into a portable AppImage.
# Adapts the v4.4 build_appimage.sh for the 5.2 install layout / naming.
#
# Notes vs. v4.4:
#   - "goo-engine" -> "goo-engine-52" binary/desktop/icon naming
#   - the AppImage runs with Blender's default user-resources path, so it
#     shares ~/.config/blender/5.2 with stock Blender 5.2; pass
#     BLENDER_USER_RESOURCES explicitly when running the AppImage, or run
#     the installed launcher (install_goo_engine_52.sh) for isolation.
#   - linuxdeploy is run with --appimage-extract-and-run where needed
#     (FUSE-less environments).
# ============================================================================
set -e

# --- Configuration ---
APP_NAME="Goo Engine 5.2"
APP_BINARY_NAME="goo-engine-52"
WRAPPER_DIR=$(pwd)
# Allow pointing at an external build tree (e.g. ~/goo52-build/build_linux)
BUILD_BIN_DIR="${BUILD_BIN_DIR:-$WRAPPER_DIR/build_linux/bin}"

WORK_DIR="$WRAPPER_DIR/build_linux_appimage"
APPDIR="$WORK_DIR/AppDir"
OUTPUT_DIR="$WORK_DIR/out"

LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
APPIMAGE_PLUGIN_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage"

echo "=== Generating AppImage for $APP_NAME ==="

if [ ! -d "$BUILD_BIN_DIR" ]; then
    echo "Error: Build directory not found at $BUILD_BIN_DIR"
    echo "Build first (build_goo_engine_52.sh) or set BUILD_BIN_DIR."
    exit 1
fi

mkdir -p "$WORK_DIR"
rm -rf "$APPDIR" "$OUTPUT_DIR"
mkdir -p "$APPDIR/usr/bin" "$OUTPUT_DIR"
cd "$WORK_DIR"

echo "Fetching linuxdeploy tools..."
if [ ! -f "linuxdeploy-x86_64.AppImage" ]; then
    wget -q "$LINUXDEPLOY_URL" -O linuxdeploy-x86_64.AppImage
    chmod +x linuxdeploy-x86_64.AppImage
fi
if [ ! -f "linuxdeploy-plugin-appimage-x86_64.AppImage" ]; then
    wget -q "$APPIMAGE_PLUGIN_URL" -O linuxdeploy-plugin-appimage-x86_64.AppImage
    chmod +x linuxdeploy-plugin-appimage-x86_64.AppImage
fi

echo "Copying application files..."
cp -r "$BUILD_BIN_DIR/"* "$APPDIR/usr/bin/"

SRC_DESKTOP="$BUILD_BIN_DIR/blender.desktop"
SRC_ICON="$BUILD_BIN_DIR/blender.svg"
if [ ! -f "$SRC_DESKTOP" ] || [ ! -f "$SRC_ICON" ]; then
    echo "Error: Resources missing in build output."
    exit 1
fi

cp "$SRC_ICON" "$APPDIR/$APP_BINARY_NAME.svg"
sed \
    -e "s|^Name=.*|Name=$APP_NAME|" \
    -e "s|^Exec=.*|Exec=blender|" \
    -e "s|^Icon=.*|Icon=$APP_BINARY_NAME|" \
    "$SRC_DESKTOP" > "$APPDIR/$APP_BINARY_NAME.desktop"

echo "Bundling dependencies..."
export VERSION="5.2.0"
export NO_STRIP=true
export PATH="$WORK_DIR:$PATH"

# FUSE-less environments (containers/CI): extract instead of mounting.
LD_ARGS=()
if [ ! -e /dev/fuse ]; then
    echo "No /dev/fuse — using --appimage-extract-and-run"
    LD_ARGS+=(--appimage-extract-and-run)
fi

"${LD_ARGS[@]}" ./linuxdeploy-x86_64.AppImage \
    --appdir "$APPDIR" \
    --executable "$APPDIR/usr/bin/blender" \
    --desktop-file "$APPDIR/$APP_BINARY_NAME.desktop" \
    --icon-file "$APPDIR/$APP_BINARY_NAME.svg" \
    --output appimage

echo "Moving output..."
if ls *.AppImage 1> /dev/null 2>&1; then
    mv *.AppImage "$OUTPUT_DIR/"
    echo "=== AppImage Generation Complete ==="
    ls -lh "$OUTPUT_DIR/"*.AppImage
else
    echo "Error: AppImage generation failed."
    exit 1
fi
