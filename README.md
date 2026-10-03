---
type: runbook
subject: Workstation desktop
artifact: Microphone Indicator plasmoid
status: partly verified — verify.sh passed on quantum 2026-10-01; shell helpers unit-tested against pactl fixtures; QML never loaded by plasmashell
owner: Valdemar Lemche
concepts: [KDE Plasma, plasmoid, PipeWire, PulseAudio, global shortcut, privacy indicator]
tags: [desktop, plasma, kde, audio, privacy]
sources:
  - https://develop.kde.org/docs/plasma/widget/setup/
  - https://develop.kde.org/docs/plasma/widget/porting_kf6/
  - https://api.kde.org/qml-org-kde-plasma-plasmoid-plasmoiditem.html
  - https://github.com/KDE/plasma-pa/blob/master/src/qml/microphoneindicator.cpp
  - https://github.com/KDE/plasma-pa/blob/master/src/qml/globalservice.cpp
  - https://docs.kde.org/stable_kf6/en/plasma-pa/kcontrol/plasma-pa/index.html
  - https://github.com/KDE/plasma-pa/blob/master/src/kded/audioshortcutsservice.cpp
date: 2026-10-01
---

# Microphone Indicator

A persistent Plasma 6 panel widget that shows whether the microphone is **muted**,
**live but idle**, or **in use by an application**, and toggles mute on left-click
or by hotkey. Targets Plasma 6.6 on Kubuntu 26.04.

**Verification state.** `verify.sh` passed on `quantum` on 2026-10-01: Plasma
6.6.6, `pactl` 17.0 against PipeWire 1.6.2, all four QML modules and all three
icons present. The shell helpers are unit-tested against captured `pactl`
fixtures (five state cases, seven toggle cases covering both backends,
`shellcheck` clean). The QML is parse-checked with `qmllint`/`qmlformat` but has
never been loaded by a running `plasmashell` — that is the remaining unknown.

### Host facts recorded 2026-10-01

| | |
|---|---|
| Plasma | 6.6.6 |
| Sound server | PipeWire 1.6.2 via `pipewire-pulse`, `pactl` 17.0 |
| Capture sources | 2 non-monitor |
| Default source | `alsa_input.usb-046d_Logitech_BRIO_47F58DBA-03.pro-input-0` |
| `/usr/bin/awk` | **GNU Awk**, not mawk |
| `mic_mute` bindings | `Meta+Alt+K`, `Microphone Mute` (XF86AudioMicMute), `Meta+Volume Mute` |

The awk is still written mawk-safe — no three-argument `match()`, no `gensub()` —
and was unit-tested under mawk 1.3.4. That costs nothing on gawk and keeps the
helpers portable, but the earlier claim that Kubuntu's `awk` *is* mawk was wrong
for this host.

## Why this exists when Plasma already has most of it

Plasma 6.6 ships two thirds of the ask, in two separate places:

| Capability | Where it already lives | Gap |
|---|---|---|
| Mic-in-use tray icon | `plasma-pa`, `src/qml/microphoneindicator.cpp` | Appears **only while recording**, so it cannot tell you "muted" at a glance |
| Mic mute shortcut | `plasma-pa`, action `mic_mute` via `globalMuteSources()`, served by the `audioshortcutsservice` KDED module | Works, but has no persistent visual counterpart |
| Click-to-mute in the panel | — | Missing |

KDE's indicator is the right model for *semantics* and this widget copies two of its
decisions deliberately:

- **"Muted" means every input is muted.** `microphoneindicator.cpp` comments that it
  "deliberately never shows the 'muted' icon unless *all* microphones are muted".
  A privacy indicator that says *silent* while a second mic is still open is worse
  than no indicator. Hence the default `muteScope = all`.
- **Streams on monitor sources do not count as recording.** `plasma-pa` filters them
  out through its `VirtualStream` role; `mic-state` filters them by checking whether
  the stream's source is a `Monitor of Sink`. Without this, a level meter or a
  loopback would read as "someone is listening".

What this widget adds is persistence and a click target.

## States

| Condition | Icon | Opacity | Marker |
|---|---|---|---|
| Every input muted | `microphone-sensitivity-muted` | 1.0 | — |
| Live, an application capturing | `microphone-sensitivity-high` | 1.0 | corner dot (`negativeTextColor`), 1/4 of the icon side |
| Live, nothing capturing | `audio-input-microphone` | `idleOpacityPercent`, default 60% | — |
| No capture device at all | `microphone-sensitivity-muted` | 1.0 | — |

Left-click toggles. The tooltip names the capturing applications, the input level,
and how many inputs are live when there is more than one.

### Panel sizing

The icon tracks the panel, so it grows and shrinks with panel thickness instead
of sitting at a fixed size. The sizing copies Plasma's own
`desktoppackage/contents/applet/DefaultCompactRepresentation.qml`:

| `Plasmoid.formFactor` | `Layout.minimumWidth` | `Layout.minimumHeight` |
|---|---|---|
| `Horizontal` | `height` | `0` |
| `Vertical` | `0` | `width` |
| anything else | `gridUnit * 3` | `gridUnit * 3` |

In a panel the cross axis is already fixed by the panel thickness, so asking for
a square on the free axis is what makes the icon follow it. **No `preferred` or
`maximum` size is set, deliberately** — a preferred size pins the icon and
defeats the whole mechanism. The `Kirigami.Icon` then fills the item, and panel
margins come from Plasma rather than from this widget.

`roundToIconSize` is set to `false`. Its default of `true` snaps the painted size
down to a size the icon theme declares, which caps a monochrome status icon at
22 or 24 px however much room the panel gives it.

**Auto mode did not produce a full-size icon on `quantum`** (48 px panel, icon
stayed at roughly 22–24 px) and the cause was not established — neither the
layout hints nor `roundToIconSize` moved it. So there is a manual override:

| Icon size | Behaviour |
|---|---|
| Follow the panel (default) | the table above; `Kirigami.Icon` fills the item |
| Fixed, 8–128 px | the glyph is sized explicitly and centred in the item |

Fixed mode sizes the **icon**, not the widget: the item is still whatever the
panel hands it, so nothing can clip, and `Layout.minimumWidth` rises to the
chosen size so a horizontal panel reserves the room. The trade is that a fixed
size does not follow a later panel resize — you set it once per panel thickness.

Root cause still open. Candidates not yet ruled out: the icon theme
(`Slot-Dark-Icons`) shipping `microphone-sensitivity-*` only at small fixed sizes
with no scalable entry, and Plasma reserving larger panel margins than assumed.
Worth revisiting if the fixed size ever needs to change.

The in-use dot is a quarter of the rendered icon's shorter side, floored at 3 px,
so it keeps its visual weight at every panel size rather than vanishing on a thin
panel or looking like a bullet hole on a thick one.

On the desktop there is no panel thickness to track, so `preferredRepresentation`
switches to the full representation there and the compact icon is only used in
panels.

## Layout

```
src/mic-indicator/
├── install.sh                      # kpackagetool6 install/upgrade + ~/.local/bin symlinks
├── uninstall.sh
├── verify.sh                       # read-only preflight; run this first
├── README.md
├── tests/
│   └── tst_radio_grouping.qml      # TESTED, qmltestrunner, no Plasma needed
└── package/
    ├── metadata.json               # net.lemche.micindicator, X-Plasma-API-Minimum-Version 6.0
    └── contents/
        ├── code/
        │   ├── mic-state           # read state  -> KEY=value lines
        │   └── mic-toggle          # mute / unmute / toggle
        ├── config/
        │   ├── config.qml
        │   └── main.xml
        └── ui/
            ├── main.qml
            └── configGeneral.qml
```

```bash
QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_radio_grouping.qml
```

The helpers live **inside** the package so the widget does not depend on
`plasmashell`'s `PATH`, and `install.sh` symlinks them into `~/.local/bin` so the
hotkey and the CLI can reach them by name.

## Backend, and why it is not the KDE one

State comes from `pactl`, not from `import org.kde.plasma.private.volume`.

KDE's own indicator uses `SourceModel` and `SourceOutputModel` from that private
module: event-driven via libpulse, no subprocesses, strictly better at runtime.
It is also explicitly private and not stable across Plasma majors, and this
workstation's handbook has enough coupled-upgrade failure modes already. The
`pactl` route costs one short pipeline per poll and survives Plasma upgrades,
PipeWire and PulseAudio alike, and can be tested from a plain shell with no
Plasma session — which is the only reason the helpers are tested at all.

**Measured cost is not yet recorded.** Before trusting the default 1000 ms
interval, measure it on the host:

```bash
# wall time and CPU for 100 state reads
time ( for i in $(seq 100); do ~/.local/bin/mic-state >/dev/null; done )
```

Record model-free conditions (`pactl --version`, PipeWire version) with the number.
If it is material while a GPU job is running, raise `pollInterval` to 2000 ms; the
icon is a status display, not a VU meter.

### `mic-state` contract

```
SOURCES=<n>     non-monitor capture sources present
UNMUTED=<n>     of those, how many are not muted
MUTED=<0|1>     1 when SOURCES>0 and UNMUTED==0
INUSE=<0|1>     1 when an application is capturing a non-monitor source
VOLUME=<0-150>  default source volume, else loudest unmuted source
DEFAULT=<name>  default source name, may be empty
APPS=<a|b|c>    capturing applications, pipe separated, may be empty
ERROR=<reason>  present only on failure
```

Exits 0 even with no sound server (then `SOURCES=0`). The awk is mawk-safe — no
three-argument `match()`, no `gensub()` — because Kubuntu's `/usr/bin/awk` is mawk.

### `mic-toggle` contract

```bash
mic-toggle [toggle|mute|unmute]
#   MIC_BACKEND=plasma|pactl   default plasma
#   MIC_SCOPE=all|default      pactl backend only, default all
#   MIC_FALLBACK=1|0           default 1
#   MIC_OSD=1|0                pactl backend only, default 0
```

Does not call `mic-state`, so the CLI keeps working if the widget is removed.
plasma-pa's shortcut only *toggles*, so `mute` and `unmute` read current state
with `pactl get-source-mute` first and invoke only when the toggle is needed.

If mute state is unreadable, `toggle` on the `pactl` backend **mutes** rather than
guessing — fail closed, consistent with the workstation's egress posture.

D-Bus client preference: `gdbus`, then `busctl`, then `qdbus6`/`qdbus`. At least
one is present on any systemd desktop.

## Install

```bash
cd "/srv/projects/second-brain/Sovereign AI Workstation/src/mic-indicator"
./verify.sh            # read-only, changes nothing
./install.sh           # user-level, no sudo
```

Then right-click the panel → *Add Widgets* → **Microphone Indicator**. If it does
not appear in the list, the shell has not rescanned:

```bash
systemctl --user restart plasma-plasmashell
```

## Hotkey

**You already have one, and it already does the right thing.** `verify.sh` found
`mic_mute` bound to three sequences on this host: `Meta+Alt+K`, the
`Microphone Mute` key (`XF86AudioMicMute`) and `Meta+Volume Mute`.

The earlier assumption that this would conflict with the widget was wrong.
plasma-pa's `mic_mute` is handled by the `audioshortcutsservice` KDED module,
which mutes **every** source:

```cpp
for (int i = 0; i < m_sourceModel->rowCount(); ++i) {
    applyGlobalSourceMute(m_sourceModel->index(i, 0), true, globalMicMuteMutedDevices);
}
```

That is the same scope as this widget's default, and it is better in one respect:
`globalMicMuteMutedDevices` records the set it muted, so unmuting does not
re-open a device you had muted deliberately. The direct `pactl` path has no such
memory.

So the design changed: **the widget's click invokes plasma-pa's own action** over
D-Bus rather than setting source mute itself.

```
org.kde.kded6        /kded             org.kde.kded6.loadModule("audioshortcutsservice")
org.kde.kglobalaccel /component/kmix   org.kde.kglobalaccel.Component.invokeShortcut("mic_mute")
```

Both calls are what `GlobalService::invokeShortcut()` and
`GlobalService::ensureKDEDModule()` in `plasma-pa/src/qml/globalservice.cpp` do.
The `loadModule` call is not optional: without it the shortcut has no handler and
the invoke silently does nothing.

The consequence is that there is **one** mute mechanism on this host. A click and
`Meta+Alt+K` are the same code path and cannot drift apart.

**Nothing to unbind. Do not create a custom shortcut** unless you want an
additional key; if you do, bind it to `~/.local/bin/mic-toggle toggle`, which
takes the same D-Bus route.

### When the direct backend is wanted instead

Switch to `pactl` in the widget's settings, or `MIC_BACKEND=pactl` on the CLI, if:

- you are outside a Plasma session (a TTY, a different desktop, a script)
- `kded6` or `audioshortcutsservice` is not running
- you want `MIC_SCOPE=default` semantics, which plasma-pa does not offer

`mic-toggle` falls back to `pactl` on its own if either D-Bus call fails, logging
one line to stderr. Set `MIC_FALLBACK=0` to make that a hard failure instead.

## Configuration

Right-click the widget → *Configure Microphone Indicator*.

| Setting | Default | Notes |
|---|---|---|
| Mute performed by | Plasma audio service | Same path as the hotkey. `Direct, via pactl` only for the cases listed above |
| Direct mute affects | Every input device | Only applies to the `pactl` backend |
| Icon size | Follow the panel | Switch to `Fixed` and pick a value if auto stays small |
| Refresh interval | 1000 ms | Raise to 2000 ms if the measurement above says so |
| Idle icon opacity | 60% | Distinguishes live-idle from in-use without a second icon |
| Overlay a marker dot | on | Corner dot while capturing |
| Pulse the marker | off | Draws the eye; distracting on a second monitor |
| Show an on-screen message | off | `pactl` backend only — plasma-pa draws its own OSD. Uses `org.kde.osdService.showText`, **unverified** method name, fails silently |
| Hide while live and idle | off | Only has an effect inside the System Tray, not on the panel proper |

## Config page: radio grouping

`QQC2.RadioButton` is `autoExclusive` by default, and auto-exclusivity groups
every radio **sharing a parent**. The three radio pairs on the config page —
backend, mute scope, icon size — are direct children of one
`Kirigami.FormLayout`, so they collapsed into a single exclusive group: choosing
*Direct, via pactl* cleared the icon-size selection, and vice versa. The
icon-size pair had the mirror-image fault, because `sizeFixed` sits inside a
`RowLayout` and so formed a private group that never cleared `sizeAuto`.

Fixed with one explicit `QQC2.ButtonGroup` per logical group. `tests/` asserts
both halves, including that the shared-parent clobbering still happens without
a group — so if a future Qt changes auto-exclusivity semantics and the explicit
groups become redundant, the test fails loudly instead of silently rotting.

Any new radio pair on that page needs its own `ButtonGroup`. There is no safe
default here.

## Known gaps

- `ui/main.qml` has never been loaded by a running `plasmashell`; it is parse-checked only,
  including the panel-sizing behaviour — the layout hints match Plasma's own default
  compact representation, but only a live panel resize proves it.
- `Plasmoid.onActivated` for the widget's own shortcut is unverified on 6.6, and
  now moot: plasma-pa's existing bindings cover the hotkey.
- `org.kde.osdService.showText` is unverified; the OSD option is off by default and
  the call is wrapped so a wrong method name cannot fail the toggle.
- Polling, not event-driven. A `pactl subscribe` watcher would cut idle cost to zero
  but the Plasma `executable` data engine only delivers output when a process exits,
  so it would need a different transport (a `systemd --user` watcher writing to
  `$XDG_RUNTIME_DIR` and a file-watching QML binding). Not worth it until the
  measurement above says polling costs something.
- Per-application mute is not offered. PipeWire can mute an individual stream, but a
  per-app indicator invites exactly the ambiguity KDE's all-muted rule avoids.
- No scroll-to-adjust input gain. Deliberate: the widget's one gesture should be
  unambiguous.

## Drift watch

Three things must change together. If you edit one, check the others:

1. `mic-state`'s output keys ↔ `applyState()` in `main.qml`.
2. `config/main.xml` entry names ↔ `cfg_*` aliases in `configGeneral.qml` ↔
   `Plasmoid.configuration.*` reads in `main.qml`.
3. The D-Bus triple in `mic-toggle` (`/component/kmix`, `invokeShortcut`,
   `audioshortcutsservice`) ↔ `plasma-pa/src/qml/globalservice.cpp`. If a future
   Plasma renames the `kmix` component, the plasma backend silently stops working
   and falls back to `pactl` with a stderr line nobody reads. `verify.sh` should
   grow a check that the component path answers on the bus.
