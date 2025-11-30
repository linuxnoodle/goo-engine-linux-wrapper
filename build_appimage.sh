#!/bin/bash
set -e

# --- Configuration ---
APP_NAME="Goo Engine"
APP_BINARY_NAME="goo-engine"
WRAPPER_DIR=$(pwd)
BUILD_BIN_DIR="$WRAPPER_DIR/build_linux/bin"

# Workspace Configuration
WORK_DIR="$WRAPPER_DIR/build_linux_appimage"
APPDIR="$WORK_DIR/AppDir"
OUTPUT_DIR="$WORK_DIR/out"

# Tools URLs
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
APPIMAGE_PLUGIN_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage"

echo "=== Generating AppImage for $APP_NAME ==="

# 1. Verify Build Exists
if [ ! -d "$BUILD_BIN_DIR" ]; then
    echo "Error: Build directory not found at $BUILD_BIN_DIR"
    echo "Please build the project first using build_goo_engine.sh"
    exit 1
fi

# 2. Prepare Directories
echo "Setting up workspace in $WORK_DIR..."
mkdir -p "$WORK_DIR"
# Clean up previous temporary directories, but keep tools if they exist
rm -rf "$APPDIR" "$OUTPUT_DIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$OUTPUT_DIR"

# Switch to the working directory so tools are downloaded/run here
cd "$WORK_DIR"

# 3. Download LinuxDeploy Tools
echo "Fetching linuxdeploy tools..."
if [ ! -f "linuxdeploy-x86_64.AppImage" ]; then
    wget -q "$LINUXDEPLOY_URL" -O linuxdeploy-x86_64.AppImage
    chmod +x linuxdeploy-x86_64.AppImage
fi

if [ ! -f "linuxdeploy-plugin-appimage-x86_64.AppImage" ]; then
    wget -q "$APPIMAGE_PLUGIN_URL" -O linuxdeploy-plugin-appimage-x86_64.AppImage
    chmod +x linuxdeploy-plugin-appimage-x86_64.AppImage
fi

# 4. Install Application into AppDir
echo "Copying application files..."
# Copy contents to usr/bin inside AppDir
cp -r "$BUILD_BIN_DIR/"* "$APPDIR/usr/bin/"

# 5. Setup Metadata
echo "Configuring metadata..."
SRC_DESKTOP="$BUILD_BIN_DIR/blender.desktop"
SRC_ICON="$BUILD_BIN_DIR/blender.svg"

if [ ! -f "$SRC_DESKTOP" ] || [ ! -f "$SRC_ICON" ]; then
    echo "Error: Resources missing in build output."
    exit 1
fi

# Copy Icon to root of AppDir with correct name
cp "$SRC_ICON" "$APPDIR/$APP_BINARY_NAME.svg"

# Modify Desktop File
# - Exec must point to the binary name relative to usr/bin (just 'blender')
# - Icon must match the SVG filename without extension
sed \
    -e "s|^Name=.*|Name=$APP_NAME|" \
    -e "s|^Exec=.*|Exec=blender|" \
    -e "s|^Icon=.*|Icon=$APP_BINARY_NAME|" \
    "$SRC_DESKTOP" > "$APPDIR/$APP_BINARY_NAME.desktop"

# 6. Run LinuxDeploy
echo "Bundling dependencies..."
export VERSION="latest"

# Disable stripping to prevent errors with newer system libraries (fixes .relr.dyn errors)
export NO_STRIP=true

# Ensure the plugin we downloaded is found in PATH
export PATH="$WORK_DIR:$PATH"

# We execute linuxdeploy from the WORK_DIR
# Removed explicit '--plugin appimage' as it causes the input/output error.
# '--output appimage' automatically triggers the plugin if it's in the PATH.
./linuxdeploy-x86_64.AppImage \
    --appdir "$APPDIR" \
    --executable "$APPDIR/usr/bin/blender" \
    --desktop-file "$APPDIR/$APP_BINARY_NAME.desktop" \
    --icon-file "$APPDIR/$APP_BINARY_NAME.svg" \
    --output appimage

# 7. Finalize
echo "Moving output..."
# Use global wildcard because linuxdeploy often replaces spaces with underscores
if ls *.AppImage 1> /dev/null 2>&1; then
    mv *.AppImage "$OUTPUT_DIR/"
    echo "=== AppImage Generation Complete ==="
    echo "Output Directory: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR/"*.AppImage
else
    echo "Error: AppImage generation failed. No .AppImage file found in $WORK_DIR"
    exit 1
fi
