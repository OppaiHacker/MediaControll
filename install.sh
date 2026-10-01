#!/usr/bin/env bash
# Installs the media module into an ML4W Quickshell config.
set -euo pipefail

QS_DIR="${QS_DIR:-$HOME/.config/quickshell}"
SRC="$(cd "$(dirname "$0")" && pwd)"

[ -f "$QS_DIR/StatusbarApp/StatusbarWindow.qml" ] || {
    echo "error: $QS_DIR/StatusbarApp/StatusbarWindow.qml not found (set QS_DIR?)" >&2
    exit 1
}

cp -v "$SRC/StatusbarApp/MediaModule.qml" "$QS_DIR/StatusbarApp/"
cp -v "$SRC/CustomTheme/LiquidGlass.qml" "$SRC/CustomTheme/GlassPanel.qml" "$QS_DIR/CustomTheme/"
mkdir -p "$QS_DIR/CustomTheme/shaders"
cp -v "$SRC"/CustomTheme/shaders/liquidglass.frag* "$QS_DIR/CustomTheme/shaders/"

if grep -q '"media"' "$QS_DIR/StatusbarApp/StatusbarWindow.qml"; then
    echo "StatusbarWindow.qml already registers \"media\", skipping patch"
else
    patch -p1 -b -d "$QS_DIR" < "$SRC/patches/statusbar-media.patch"
    echo "patched (original kept as StatusbarWindow.qml.orig)"
fi

echo
echo 'Done. Add "media" to a module list in ~/.config/ml4w-statusbar/statusbar.json, e.g.'
echo '  { "modules": { "left": ["terminal", "workspaces", "media"] } }'
