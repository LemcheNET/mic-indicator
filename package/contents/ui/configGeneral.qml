import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_pollInterval: pollSpin.value
    property string cfg_iconSizeMode: "auto"
    property alias cfg_iconSizePx: iconSizeSpin.value
    property string cfg_backend: "plasma"
    property string cfg_muteScope: "all"
    property alias cfg_idleOpacityPercent: idleSpin.value
    property alias cfg_showInUseDot: dotCheck.checked
    property alias cfg_pulseInUseDot: pulseCheck.checked
    property alias cfg_showOsd: osdCheck.checked
    property alias cfg_hideWhenIdle: hideCheck.checked

    Kirigami.FormLayout {
        // RadioButton is autoExclusive by default, and auto-exclusivity groups
        // every radio sharing a parent. All of these are direct children of one
        // FormLayout, so without explicit groups the backend, scope and icon
        // size radios form a single group and clobber each other. ButtonGroup
        // also fixes the reverse case: a radio nested in a RowLayout (sizeFixed)
        // would otherwise be in a group of its own and never clear its sibling.
        // Verified by tests/tst_radio_grouping.qml.
        QQC2.ButtonGroup {
            buttons: [backendPlasma, backendPactl]
        }

        QQC2.ButtonGroup {
            buttons: [scopeAll, scopeDefault]
        }

        QQC2.ButtonGroup {
            buttons: [sizeAuto, sizeFixed]
        }

        QQC2.RadioButton {
            id: backendPlasma

            Kirigami.FormData.label: i18n("Mute performed by:")
            text: i18n("Plasma audio service")
            checked: page.cfg_backend === "plasma"
            onToggled: if (checked) page.cfg_backend = "plasma"
        }

        QQC2.RadioButton {
            id: backendPactl

            text: i18n("Direct, via pactl")
            checked: page.cfg_backend === "pactl"
            onToggled: if (checked) page.cfg_backend = "pactl"
        }

        QQC2.Label {
            text: i18n("The Plasma service is the same path your mute hotkey uses, so a\nclick and the hotkey cannot disagree. It mutes every input and\nremembers which ones it muted, so unmuting will not re-open a\ndevice you muted yourself.")
            opacity: 0.7
            font: Kirigami.Theme.smallFont
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: scopeAll

            Kirigami.FormData.label: i18n("Direct mute affects:")
            text: i18n("Every input device")
            enabled: backendPactl.checked
            checked: page.cfg_muteScope === "all"
            onToggled: if (checked) page.cfg_muteScope = "all"
        }

        QQC2.RadioButton {
            id: scopeDefault

            text: i18n("Default input device only")
            enabled: backendPactl.checked
            checked: page.cfg_muteScope === "default"
            onToggled: if (checked) page.cfg_muteScope = "default"
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: sizeAuto

            Kirigami.FormData.label: i18n("Icon size:")
            text: i18n("Follow the panel")
            checked: page.cfg_iconSizeMode === "auto"
            onToggled: if (checked) page.cfg_iconSizeMode = "auto"
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                id: sizeFixed

                text: i18n("Fixed:")
                checked: page.cfg_iconSizeMode === "fixed"
                onToggled: if (checked) page.cfg_iconSizeMode = "fixed"
            }

            QQC2.SpinBox {
                id: iconSizeSpin

                enabled: sizeFixed.checked
                from: 8
                to: 128
                stepSize: 2
                textFromValue: (value) => i18n("%1 px", value)
                valueFromText: (text) => parseInt(text, 10)
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: pollSpin

            Kirigami.FormData.label: i18n("Refresh interval:")
            from: 250
            to: 10000
            stepSize: 250
            textFromValue: (value) => i18n("%1 ms", value)
            valueFromText: (text) => parseInt(text, 10)
        }

        QQC2.SpinBox {
            id: idleSpin

            Kirigami.FormData.label: i18n("Idle icon opacity:")
            from: 20
            to: 100
            stepSize: 5
            textFromValue: (value) => i18n("%1%", value)
            valueFromText: (text) => parseInt(text, 10)
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: dotCheck

            Kirigami.FormData.label: i18n("While recording:")
            text: i18n("Overlay a marker dot")
        }

        QQC2.CheckBox {
            id: pulseCheck

            text: i18n("Pulse the marker")
            enabled: dotCheck.checked
        }

        QQC2.CheckBox {
            id: osdCheck

            Kirigami.FormData.label: i18n("On change:")
            text: i18n("Show an on-screen message")
            enabled: backendPactl.checked
            // The Plasma service draws its own OSD, so this would double up.
        }

        QQC2.CheckBox {
            id: hideCheck

            Kirigami.FormData.label: i18n("In the System Tray:")
            text: i18n("Hide while live and idle")
        }
    }
}
