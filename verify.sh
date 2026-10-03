#!/usr/bin/env bash
# verify.sh -- read-only preflight and health check for the Microphone Indicator.
#
# Changes nothing. Run it before install.sh, and again after, to see what the
# plasmoid will actually have available on this host.
#
# Exit status: 0 if every required check passed, 1 otherwise.
set -uo pipefail

APPLET_ID="net.lemche.micindicator"
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fail=0
warn=0

ok()   { printf '  \033[32mok\033[0m    %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; fail=1; }
note() { printf '  \033[33mwarn\033[0m  %s\n' "$*"; warn=1; }
info() { printf '        %s\n' "$*"; }

echo "== desktop =="
if command -v plasmashell >/dev/null 2>&1; then
    v=$(plasmashell --version 2>/dev/null | awk '{print $NF}')
    case "$v" in
        6.*) ok "plasmashell $v" ;;
        *)   bad "plasmashell $v -- this package targets Plasma 6" ;;
    esac
else
    bad "plasmashell not found"
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    ok "kpackagetool6 present"
else
    bad "kpackagetool6 not found (needed to install the package)"
fi

echo "== QML modules =="
qmldirs=$(find /usr/lib /usr/lib64 -maxdepth 7 -type d -name plasma5support \
            -path '*qml/org/kde/plasma/*' 2>/dev/null | head -n1)
if [ -n "$qmldirs" ]; then
    ok "org.kde.plasma.plasma5support at $qmldirs"
else
    bad "org.kde.plasma.plasma5support not found -- install qml6-module-org-kde-plasma-plasma5support"
fi

for m in plasmoid core components kirigami; do
    case "$m" in
        kirigami) p=$(find /usr/lib /usr/lib64 -maxdepth 6 -type d -path '*qml/org/kde/kirigami' 2>/dev/null | head -n1) ;;
        *)        p=$(find /usr/lib /usr/lib64 -maxdepth 7 -type d -path "*qml/org/kde/plasma/$m" 2>/dev/null | head -n1) ;;
    esac
    if [ -n "$p" ]; then ok "QML module $m"; else bad "QML module $m missing"; fi
done

echo "== audio =="
if command -v pactl >/dev/null 2>&1; then
    ok "pactl $(pactl --version 2>/dev/null | head -n1 | awk '{print $NF}')"
    if srv=$(pactl info 2>/dev/null); then
        info "$(printf '%s\n' "$srv" | grep -E '^(Server Name|Server Version|Default Source)' | tr '\n' '; ')"
    else
        bad "pactl cannot reach a sound server (is pipewire-pulse running?)"
    fi
else
    bad "pactl not found -- install pulseaudio-utils"
fi
if command -v awk >/dev/null 2>&1; then
    ok "awk ($(awk -W version 2>&1 | head -n1 | cut -d' ' -f1-2))"
else
    bad "awk not found"
fi

echo "== icons =="
for i in microphone-sensitivity-muted microphone-sensitivity-high audio-input-microphone; do
    if find /usr/share/icons "$HOME/.local/share/icons" -name "$i.*" -print -quit 2>/dev/null | grep -q .; then
        ok "icon $i"
    else
        note "icon $i not found in the installed themes -- the widget will fall back to a blank icon"
    fi
done

echo "== helpers =="
for f in mic-state mic-toggle; do
    p="$here/package/contents/code/$f"
    if [ -f "$p" ]; then
        if [ -x "$p" ]; then
            ok "$f present and executable"
        else
            note "$f present but not executable (install.sh fixes this)"
        fi
        if bash -n "$p" 2>/dev/null; then ok "$f parses"; else bad "$f has a syntax error"; fi
    else
        bad "$f missing from the package"
    fi
done

echo "== state right now =="
if [ -f "$here/package/contents/code/mic-state" ]; then
    out=$(bash "$here/package/contents/code/mic-state" 2>&1)
    printf '%s\n' "$out" | sed 's/^/        /'
    case "$out" in
        *SOURCES=0*) note "no capture source visible -- the widget will show \"No audio input device\"" ;;
    esac
fi

echo "== installation =="
if command -v kpackagetool6 >/dev/null 2>&1 &&
   kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$APPLET_ID"; then
    ok "$APPLET_ID is installed"
else
    info "$APPLET_ID is not installed yet"
fi

echo "== mute mechanism =="
dbus_client=""
for c in gdbus busctl qdbus6 qdbus; do
    if command -v "$c" >/dev/null 2>&1; then dbus_client=$c; break; fi
done
if [ -n "$dbus_client" ]; then
    ok "D-Bus client: $dbus_client"
else
    bad "no gdbus/busctl/qdbus found -- the plasma backend cannot work"
fi

# Read-only introspection: does plasma-pa's shortcut component answer?
if command -v gdbus >/dev/null 2>&1; then
    if gdbus introspect --session --dest org.kde.kglobalaccel \
            --object-path /component/kmix 2>/dev/null | grep -q invokeShortcut; then
        ok "org.kde.kglobalaccel /component/kmix exposes invokeShortcut"
    else
        note "/component/kmix did not answer -- the widget will fall back to pactl"
        info "this is expected outside a running Plasma session"
    fi
    mods=$(gdbus call --session --dest org.kde.kded6 --object-path /kded \
            --method org.kde.kded6.loadedModules 2>/dev/null || true)
    case "$mods" in
        *audioshortcutsservice*) ok "KDED module audioshortcutsservice is loaded" ;;
        "") info "could not list KDED modules (kded6 not reachable)" ;;
        *) info "audioshortcutsservice not loaded yet -- mic-toggle loads it on demand" ;;
    esac
else
    info "gdbus absent; skipping the read-only bus checks"
fi

echo "== hotkey =="
sc="$HOME/.config/kglobalshortcutsrc"
if [ -f "$sc" ]; then
    hit=$(grep -n 'mic_mute' "$sc" 2>/dev/null || true)
    if [ -n "$hit" ]; then
        ok "plasma-pa already owns a microphone mute shortcut:"
        printf '%s\n' "$hit" | sed 's/^/        /'
        info "keep it. plasma-pa's mic_mute mutes every source, which is the"
        info "same scope the widget uses, and the widget invokes that very"
        info "action -- so a click and the hotkey cannot disagree."
    else
        note "no mic_mute binding found"
        info "bind one in System Settings -> Keyboard -> Shortcuts -> Audio Volume"
        info "-> Mute Microphone, or bind a command to: mic-toggle toggle"
    fi
    if grep -q 'mic-toggle' "$sc" 2>/dev/null; then
        info "a custom shortcut on mic-toggle also exists (harmless, same route)"
    fi
else
    info "$sc does not exist yet"
fi

echo
if [ "$fail" -ne 0 ]; then
    echo "RESULT: required checks failed -- fix the FAIL lines before installing."
    exit 1
fi
if [ "$warn" -ne 0 ]; then echo "RESULT: ok, with warnings."; else echo "RESULT: ok."; fi
exit 0
