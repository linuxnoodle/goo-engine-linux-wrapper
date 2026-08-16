#!/bin/bash
# ============================================================================
# Goo Engine 5.2 Install Script  (goo-engine-linux-wrapper, v5.2-release)
#
# Installs the freshly built 5.2 binary to ~/.local/share/goo-engine-52 with
# an ISOLATED user-resources directory (~/.config/goo-engine-52).
#
# Isolation matters: the 5.2 binary reports version 5.2, so without this it
# shares ~/.config/blender/5.2 with any stock Blender 5.2 install (prefs,
# addons, enabled-engine state).  goo-engine 4.4 avoided this because it
# uses its own version dir (~/.config/blender/4.4) -- 5.2 does not, hence the
# BLENDER_USER_RESOURCES launcher wrapper.
# ============================================================================
set -e

WRAPPER_DIR=$(pwd)
BUILD_BIN_DIR="$WRAPPER_DIR/build_linux/bin"
APP_NAME="Goo Engine 5.2"
APP_BINARY_NAME="goo-engine-52"

INSTALL_DIR="$HOME/.local/share/goo-engine-52"
BIN_LINK_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
USER_RESOURCES="$HOME/.config/goo-engine-52"

echo "=== Installing $APP_NAME ==="

if [ ! -f "$BUILD_BIN_DIR/blender" ]; then
    echo "Error: Compiled binary not found at $BUILD_BIN_DIR/blender"
    echo "Please run build_goo_engine_52.sh first."
    exit 1
fi

mkdir -p "$INSTALL_DIR" "$BIN_LINK_DIR" "$DESKTOP_DIR" "$ICON_DIR" "$USER_RESOURCES"

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi
cp -r "$BUILD_BIN_DIR" "$INSTALL_DIR"

# Launcher: isolates user resources from stock Blender 5.2.
cat > "$BIN_LINK_DIR/$APP_BINARY_NAME" <<EOF
#!/bin/bash
# Goo Engine 5.2 -- isolated user resources (no clash with stock Blender 5.2)
export BLENDER_USER_RESOURCES="\$HOME/.config/goo-engine-52"
exec "$INSTALL_DIR/blender" "\$@"
EOF
chmod +x "$BIN_LINK_DIR/$APP_BINARY_NAME"

# Icon + desktop entry.
if [ -f "$INSTALL_DIR/blender.svg" ]; then
    cp "$INSTALL_DIR/blender.svg" "$ICON_DIR/$APP_BINARY_NAME.svg"
fi
if [ -f "$INSTALL_DIR/blender.desktop" ]; then
    sed \
        -e "s|^Name=.*|Name=$APP_NAME|" \
        -e "s|^Exec=.*|Exec=$BIN_LINK_DIR/$APP_BINARY_NAME %f|" \
        -e "s|^Icon=.*|Icon=$APP_BINARY_NAME|" \
        "$INSTALL_DIR/blender.desktop" > "$DESKTOP_DIR/$APP_BINARY_NAME.desktop"
    chmod +x "$DESKTOP_DIR/$APP_BINARY_NAME.desktop"
fi

command -v update-desktop-database &>/dev/null && update-desktop-database "$DESKTOP_DIR" || true
command -v gtk-update-icon-cache &>/dev/null && gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" &>/dev/null || true

echo "=== Installation Complete ==="
echo "Launch: '$APP_BINARY_NAME' (or App Menu: '$APP_NAME')"
echo "User resources isolated in: $USER_RESOURCES"
