/*
 * Microphone Indicator -- a persistent mute/in-use indicator for Plasma 6.
 *
 * State comes from contents/code/mic-state, mutation from contents/code/mic-toggle.
 * Nothing here imports a private KDE API, so a Plasma point release cannot
 * break it; the cost is one short-lived pactl pipeline per poll.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ---- helper paths -------------------------------------------------------
    // Resolved inside the installed package so the widget works whether or not
    // ~/.local/bin is on plasmashell's PATH.
    readonly property string codeDir: {
        let u = Qt.resolvedUrl("../code/").toString();
        if (u.startsWith("file://")) {
            u = u.substring(7);
        }
        return decodeURIComponent(u);
    }
    readonly property string stateCmd: "'" + codeDir + "mic-state'"
    readonly property string toggleCmd: "MIC_BACKEND=" + Plasmoid.configuration.backend
        + " MIC_SCOPE=" + Plasmoid.configuration.muteScope
        + " MIC_OSD=" + (Plasmoid.configuration.showOsd ? "1" : "0")
        + " '" + codeDir + "mic-toggle' toggle"
    readonly property string settingsCmd: "kcmshell6 kcm_pulseaudio"

    // ---- observed state -----------------------------------------------------
    property bool everUpdated: false
    property bool muted: false
    property bool inUse: false
    property int sourceCount: 0
    property int unmutedCount: 0
    property int inputVolume: 0
    property string defaultSource: ""
    property var recordingApps: []
    property string lastError: ""
    property bool busy: false

    readonly property bool noDevice: everUpdated && sourceCount === 0


    // ---- presentation -------------------------------------------------------
    readonly property string iconName: {
        if (noDevice || muted) {
            return "microphone-sensitivity-muted";
        }
        if (inUse) {
            return "microphone-sensitivity-high";
        }
        return "audio-input-microphone";
    }

    readonly property real iconOpacity: {
        if (!everUpdated) {
            return 0.4;
        }
        if (muted || inUse) {
            return 1.0;
        }
        return Plasmoid.configuration.idleOpacityPercent / 100.0;
    }

    Plasmoid.icon: iconName

    Plasmoid.status: {
        if (!Plasmoid.configuration.hideWhenIdle) {
            return PlasmaCore.Types.ActiveStatus;
        }
        return (muted || inUse) ? PlasmaCore.Types.ActiveStatus
                                : PlasmaCore.Types.PassiveStatus;
    }

    toolTipMainText: {
        if (!everUpdated) {
            return i18n("Microphone: reading state…");
        }
        if (lastError !== "") {
            return i18n("Microphone: state unavailable");
        }
        if (noDevice) {
            return i18n("No audio input device");
        }
        if (muted) {
            return i18n("Microphone muted");
        }
        if (inUse) {
            return i18n("Microphone in use");
        }
        return i18n("Microphone live, nothing recording");
    }

    toolTipSubText: {
        if (lastError !== "") {
            return lastError;
        }
        if (noDevice) {
            return "";
        }
        const lines = [];
        if (inUse && recordingApps.length > 0) {
            lines.push(i18n("Recording: %1", recordingApps.join(", ")));
        }
        if (!muted) {
            lines.push(i18n("Input level: %1%", inputVolume));
        }
        if (sourceCount > 1) {
            lines.push(i18np("%1 input, %2 live", "%1 inputs, %2 live",
                             sourceCount, unmutedCount));
        }
        lines.push(muted ? i18n("Click or press the hotkey to unmute")
                         : i18n("Click or press the hotkey to mute"));
        return lines.join("\n");
    }

    // In a panel the compact icon is the whole point. On the desktop there is
    // no panel thickness to track, so the full representation is the sane one.
    preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                              || Plasmoid.formFactor === PlasmaCore.Types.Vertical)
                             ? compactRepresentation : fullRepresentation

    // ---- plumbing -----------------------------------------------------------
    Plasma5Support.DataSource {
        id: exec

        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
            if (sourceName === root.stateCmd) {
                root.busy = false;
                root.applyState(data["stdout"] || "", data["exit code"]);
            } else if (sourceName === root.toggleCmd) {
                // Reconcile against the server rather than trusting the
                // optimistic flip done at click time.
                root.poll();
            }
        }

        function run(cmd) {
            if (cmd) {
                connectSource(cmd);
            }
        }
    }

    function poll() {
        if (busy) {
            return;
        }
        busy = true;
        exec.run(stateCmd);
    }

    function applyState(stdout, exitCode) {
        if (exitCode !== 0) {
            lastError = i18n("mic-state exited %1", exitCode);
            everUpdated = true;
            return;
        }
        const kv = {};
        for (const line of stdout.split("\n")) {
            const eq = line.indexOf("=");
            if (eq > 0) {
                kv[line.substring(0, eq)] = line.substring(eq + 1);
            }
        }
        if (!("SOURCES" in kv)) {
            lastError = i18n("mic-state returned no usable output");
            everUpdated = true;
            return;
        }
        lastError = ("ERROR" in kv) ? kv["ERROR"] : "";
        sourceCount = parseInt(kv["SOURCES"], 10) || 0;
        unmutedCount = parseInt(kv["UNMUTED"], 10) || 0;
        muted = kv["MUTED"] === "1";
        inUse = kv["INUSE"] === "1";
        inputVolume = parseInt(kv["VOLUME"], 10) || 0;
        defaultSource = kv["DEFAULT"] || "";
        recordingApps = (kv["APPS"] || "") === "" ? [] : kv["APPS"].split("|");
        everUpdated = true;
    }

    function toggleMute() {
        if (noDevice) {
            return;
        }
        muted = !muted;           // optimistic, reconciled by the poll above
        exec.run(toggleCmd);
    }

    Timer {
        interval: Math.max(250, Plasmoid.configuration.pollInterval)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // Fires when the widget's own global shortcut is pressed. Unverified on
    // Plasma 6.6; the supported route is a custom shortcut on mic-toggle.
    Connections {
        target: Plasmoid
        ignoreUnknownSignals: true
        function onActivated() {
            root.toggleMute();
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Mute all inputs")
            icon.name: "microphone-sensitivity-muted"
            visible: !root.noDevice && !root.muted
            onTriggered: root.toggleMute()
        },
        PlasmaCore.Action {
            text: i18n("Unmute all inputs")
            icon.name: "microphone-sensitivity-high"
            visible: !root.noDevice && root.muted
            onTriggered: root.toggleMute()
        },
        PlasmaCore.Action {
            text: i18n("Audio settings…")
            icon.name: "configure"
            onTriggered: exec.run(root.settingsCmd)
        }
    ]

    // ---- compact (panel) ----------------------------------------------------
    compactRepresentation: MouseArea {
        id: compact

        readonly property bool fixedSize: Plasmoid.configuration.iconSizeMode === "fixed"
        readonly property int fixedPx: Plasmoid.configuration.iconSizePx

        // Sizing follows Plasma's own DefaultCompactRepresentation. In a panel
        // the cross axis is fixed by the panel thickness, so asking for a
        // square on the free axis makes the icon track the panel as it is
        // resized. Setting no preferred or maximum size is deliberate: a
        // preferred size would pin the icon and defeat the whole point.
        Layout.minimumWidth: {
            if (fixedSize) {
                return fixedPx;
            }
            switch (Plasmoid.formFactor) {
            case PlasmaCore.Types.Vertical:
                return 0;
            case PlasmaCore.Types.Horizontal:
                return height;
            default:
                return Kirigami.Units.gridUnit * 3;
            }
        }

        Layout.minimumHeight: {
            if (fixedSize) {
                return fixedPx;
            }
            switch (Plasmoid.formFactor) {
            case PlasmaCore.Types.Vertical:
                return width;
            case PlasmaCore.Types.Horizontal:
                return 0;
            default:
                return Kirigami.Units.gridUnit * 3;
            }
        }

        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.toggleMute()

        Kirigami.Icon {
            id: micIcon

            // Fixed mode sizes the glyph itself and centres it; the item can
            // still be whatever the panel hands it. Auto mode fills.
            anchors.centerIn: parent
            width: compact.fixedSize ? compact.fixedPx : compact.width
            height: compact.fixedSize ? compact.fixedPx : compact.height
            source: root.iconName
            // Default is true, which snaps the painted size down to the nearest
            // size the icon theme declares. For a monochrome status icon that
            // tops out at 22 or 24 px, that caps the glyph well below a thick
            // panel. Off means the item size governs and the SVG is scaled.
            roundToIconSize: false
            opacity: compact.containsMouse ? 1.0 : root.iconOpacity
            active: compact.containsMouse

            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }
        }

        // In-use marker: a small dot in the corner, so "live and recording"
        // is distinguishable from "live and idle" at panel size.
        Rectangle {
            // Proportional to the rendered icon, not to a fixed unit, so the
            // marker keeps its weight at every panel thickness.
            readonly property int side: Math.max(3, Math.round(Math.min(micIcon.width, micIcon.height) / 4))

            visible: root.inUse && !root.muted && Plasmoid.configuration.showInUseDot
            width: side
            height: side
            radius: side / 2
            color: Kirigami.Theme.negativeTextColor
            anchors.right: micIcon.right
            anchors.bottom: micIcon.bottom

            SequentialAnimation on opacity {
                running: Plasmoid.configuration.pulseInUseDot
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutQuad }
            }
        }
    }

    // ---- full (desktop placement) ------------------------------------------
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: root.iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
            }

            ColumnLayout {
                spacing: 0

                PlasmaComponents3.Label {
                    text: root.toolTipMainText
                    font.bold: true
                }

                PlasmaComponents3.Label {
                    text: root.toolTipSubText
                    opacity: 0.8
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            enabled: !root.noDevice
            icon.name: root.muted ? "microphone-sensitivity-high"
                                  : "microphone-sensitivity-muted"
            text: root.muted ? i18n("Unmute all inputs") : i18n("Mute all inputs")
            onClicked: root.toggleMute()
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
