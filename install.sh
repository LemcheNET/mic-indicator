#!/usr/bin/env bash
# install.sh -- install or upgrade the Microphone Indicator plasmoid.
#
# User-level only. No sudo. Touches:
#   ~/.local/share/plasma/plasmoids/net.lemche.micindicator/   (the package)
#   ~/.local/bin/mic-state, ~/.local/bin/mic-toggle            (symlinks)
#
# Run ./verify.sh first; it is read-only and reports what is missing.
set -euo pipefail

APPLET_ID="net.lemche.micindicator"
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pkg="$here/package"
bindir="${XDG_BIN_HOME:-$HOME/.local/bin}"
installed="$HOME/.local/share/plasma/plasmoids/$APPLET_ID"

command -v kpackagetool6 >/dev/null 2>&1 || {
    echo "install.sh: kpackagetool6 not found (install plasma-framework / libkf6package-bin)" >&2
    exit 1
}
[ -f "$pkg/metadata.json" ] || { echo "install.sh: $pkg/metadata.json missing" >&2; exit 1; }

echo "==> marking helpers executable"
chmod 0755 "$pkg/contents/code/mic-state" "$pkg/contents/code/mic-toggle"

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$APPLET_ID"; then
    echo "==> upgrading $APPLET_ID"
    kpackagetool6 --type Plasma/Applet --upgrade "$pkg"
else
    echo "==> installing $APPLET_ID"
    kpackagetool6 --type Plasma/Applet --install "$pkg"
fi

# kpackagetool6 copies the tree; make sure the copy kept the exec bits.
if [ -d "$installed/contents/code" ]; then
    chmod 0755 "$installed/contents/code/mic-state" "$installed/contents/code/mic-toggle" || true
fi

echo "==> linking helpers into $bindir"
mkdir -p "$bindir"
ln -sf "$installed/contents/code/mic-state"  "$bindir/mic-state"
ln -sf "$installed/contents/code/mic-toggle" "$bindir/mic-toggle"

echo
echo "Installed. Next:"
echo "  1. Add the widget:  right-click the panel -> Add Widgets -> \"Microphone Indicator\""
echo "     If it does not appear, restart the shell:  systemctl --user restart plasma-plasmashell"
echo "  2. Hotkey: nothing to do if plasma-pa's \"Mute Microphone\" is already bound."
echo "     The widget invokes that same action, so a click and the hotkey agree."
echo "     Run ./verify.sh to see the current bindings."
echo
echo "Current state:"
"$installed/contents/code/mic-state" 2>/dev/null | sed 's/^/  /' || echo "  (mic-state could not run)"
