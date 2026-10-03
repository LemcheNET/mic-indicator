#!/usr/bin/env bash
# uninstall.sh -- remove the Microphone Indicator plasmoid and its symlinks.
#
# Does not remove the widget from your panel first; Plasma drops it on the next
# shell restart. It does not touch any keyboard shortcut you created, and it
# does not restore plasma-pa's "Mute Microphone" binding.
set -euo pipefail

APPLET_ID="net.lemche.micindicator"
bindir="${XDG_BIN_HOME:-$HOME/.local/bin}"

if command -v kpackagetool6 >/dev/null 2>&1 &&
   kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$APPLET_ID"; then
    echo "==> removing $APPLET_ID"
    kpackagetool6 --type Plasma/Applet --remove "$APPLET_ID"
else
    echo "==> $APPLET_ID is not installed"
fi

for f in mic-state mic-toggle; do
    if [ -L "$bindir/$f" ]; then
        echo "==> removing symlink $bindir/$f"
        rm -f "$bindir/$f"
    fi
done

echo
echo "Done. Remaining by design:"
echo "  - any custom shortcut you bound to mic-toggle (remove it in System Settings)"
echo "  - plasma-pa's \"Mute Microphone\" binding, if you cleared it"
