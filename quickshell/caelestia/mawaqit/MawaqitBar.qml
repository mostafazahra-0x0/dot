pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Optional bar pill for Caelestia showing the next prayer + countdown.
// Style mirrors modules/bar/components/Clock.qml (pill, tertiary accent).
// Not installed by install.sh by default — the primary surface is the
// sidebar card (MawaqitCard.qml). Wire it into Bar.qml manually if wanted.
StyledRect {
    id: root

    required property var service

    readonly property color colour: root.service.nextIsNow ? Colours.palette.m3primary : Colours.palette.m3tertiary

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Tokens.rounding.full

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "mosque"
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            animate: true
            text: root.service.prayers.length === 0 ? "…" : (root.service.nextIsNow ? root.service.displayLabel(root.service.nextName) : root.service.displayLabel(root.service.nextName) + " " + root.service.countdown)
            font: Tokens.font.body.builders.small.scale(1.1).build()
            color: root.colour
        }
    }
}
