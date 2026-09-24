pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Sidebar prayer-times card for Caelestia.
// Visual port of the Noctalia `ycf/mawaqit` panel, restyled with Caelestia
// theme tokens (Colours / Tokens) so it follows the active scheme, light or
// dark, like every other sidebar surface.
//
// Expects a `service` object with the MawaqitService API (see
// MawaqitService.qml). When the service is a QML singleton you can simply do:
//   MawaqitCard { service: MawaqitService }
StyledRect {
    id: root

    required property var service

    readonly property var prayerIcons: ({
        Fajr: "dark_mode",
        Sunrise: "wb_twilight",
        Dhuhr: "light_mode",
        Asr: "sunny",
        Maghrib: "contrast",
        Isha: "bedtime",
        Imsak: "schedule"
    })

    // Fixed prayer order. Rows iterate over these plain strings (never over
    // the service's objects) and look up each time by name, so rendering
    // cannot break even if the service list is empty or resets.
    readonly property list<string> prayerOrder: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    // All installed font families, for the font picker dropdowns.
    readonly property var systemFonts: Qt.fontFamilies().sort()

    property bool showSettings: false

    // Fold driver: 0 = fully open, 1 = fully folded. Bound to the
    // persisted collapsed state; the Behavior animates every toggle so
    // collapsing/re-opening folds smoothly instead of snapping.
    property real foldFactor: root.service.collapsed ? 1 : 0
    Behavior on foldFactor {
        Anim {}
    }

    // Header title. When collapsed to header-only mode, keep the next
    // prayer + countdown visible so the card stays useful while freeing
    // sidebar space for notifications.
    function headerTitle(): string {
        if (root.showSettings)
            return qsTr("Settings");
        if (root.service.collapsed && root.service.nextName !== "") {
            const label = root.service.displayLabel(root.service.nextName);
            if (root.service.nextIsNow)
                return qsTr("%1 · now").arg(label);
            return qsTr("%1 · %2").arg(label).arg(root.service.countdown);
        }
        return qsTr("Prayer times");
    }

    function prayerTime(prayerName: string): string {
        const found = root.service.prayers.find(p => p && p.name === prayerName);
        return (found && found.time) || "";
    }

    // Effective families: empty service value = follow the Caelestia theme
    // font. Returns a copy of the token base font with the family swapped.
    function arabicFamily(): string {
        if (root.service.arabicFontFamily !== "")
            return root.service.arabicFontFamily;
        return root.service.fontFamily;
    }

    function themedFont(base: font, family: string): font {
        if (family === "")
            return base;
        return Qt.font({
            family: family,
            pointSize: base.pointSize,
            pixelSize: base.pixelSize,
            weight: base.weight,
            italic: base.italic,
            underline: base.underline,
            strikeout: base.strikeout
        });
    }

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainerLow

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        // ── Header ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "mosque"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: root.headerTitle()
                color: Colours.palette.m3onSurface
                font: root.themedFont(Tokens.font.title.builders.small.build(), root.service.fontFamily)
                elide: Text.ElideRight
            }

            IconButton {
                visible: !root.showSettings && !root.service.collapsed && root.service && root.service.azanPlaying
                icon: "stop"
                type: IconButton.Tonal
                font: Tokens.font.icon.small
                onClicked: root.service.stopAzan()
            }

            IconButton {
                visible: !root.showSettings && !root.service.collapsed
                icon: "refresh"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                onClicked: root.service.refresh()
            }

            IconButton {
                icon: root.service.collapsed ? "expand_more" : "expand_less"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                onClicked: {
                    root.service.collapsed = !root.service.collapsed;
                    if (root.service.collapsed)
                        root.showSettings = false;
                }
            }

            IconButton {
                icon: root.showSettings ? "arrow_back" : "settings"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                onClicked: {
                    if (root.service.collapsed) {
                        // Opening settings from a collapsed card re-opens it.
                        root.service.collapsed = false;
                        root.showSettings = true;
                    } else {
                        root.showSettings = !root.showSettings;
                    }
                }
            }
        }

        // ── Collapsible body: clipped container whose height + opacity
        // follow foldFactor. The card (and the notification dock below it)
        // resize smoothly while the body folds away or unfolds.
        Item {
            id: bodyClip

            Layout.fillWidth: true
            Layout.preferredHeight: bodyCol.implicitHeight * (1 - root.foldFactor)
            visible: !root.service.collapsed || root.foldFactor < 1
            clip: true
            opacity: 1 - root.foldFactor

            ColumnLayout {
                id: bodyCol

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.small

                // ── Dates ─────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: !root.showSettings && ((root.service.gregorianDate !== "") || (root.service.hijriDate !== ""))

                StyledText {
                    Layout.fillWidth: true
                    text: root.service.gregorianDate
                    color: Colours.palette.m3onSurfaceVariant
                    font: root.themedFont(Tokens.font.body.small, root.service.fontFamily)
                    elide: Text.ElideRight
                }

                StyledText {
                    text: root.service.hijriDateAr !== "" ? root.service.hijriDateAr : root.service.hijriDate
                    color: root.service.hijriMonth === 9 ? Colours.palette.m3primary : Colours.palette.m3secondary
                    font: root.themedFont(Tokens.font.body.builders.small.weight(Font.Medium).build(), root.arabicFamily())
                }
            }

                // ── Countdown banner ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                spacing: 2
                visible: !root.showSettings && (root.service.prayers.length > 0) && (root.service.nextName !== "")

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.service.nextIsNow ? qsTr("Now: %1").arg(root.service.displayLabel(root.service.nextName)) : qsTr("%1 in").arg(root.service.displayLabel(root.service.nextName))
                    color: Colours.palette.m3onSurfaceVariant
                    font: root.themedFont(Tokens.font.body.small, root.service.fontFamily)
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    animate: true
                    text: root.service.nextIsNow ? qsTr("now") : root.service.countdown
                    color: Colours.palette.m3primary
                    font: root.themedFont(Tokens.font.headline.builders.medium.weight(Font.DemiBold).build(), root.service.fontFamily)
                }
            }

                // ── Loading / error ───────────────────────────────────────────
            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                horizontalAlignment: Text.AlignHCenter
                visible: !root.showSettings && root.service.prayers.length === 0
                text: root.service.error !== "" ? root.service.error : qsTr("Loading prayer times…")
                color: root.service.error !== "" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: root.themedFont(Tokens.font.body.small, root.service.fontFamily)
                wrapMode: Text.Wrap
            }

                // ── Imsak (Ramadan only, like the Noctalia plugin) ────────────
            PrayerRow {
                visible: !root.showSettings && root.service.hijriMonth === 9 && root.service.imsakTime !== ""
                prayerName: "Imsak"
                prayerTime: root.service.imsakTime
                prayerIcon: root.prayerIcons.Imsak
                highlight: false
                accent: Colours.palette.m3secondary
            }

                // ── Prayer rows ───────────────────────────────────────────────
            Repeater {
                model: root.prayerOrder

                delegate: PrayerRow {
                    required property string modelData
                    readonly property string key: modelData
visible: !root.showSettings
                prayerName: root.service.displayLabel(key)
                    prayerTime: root.prayerTime(key)
                    prayerIcon: root.prayerIcons[key] ?? "schedule"
                    highlight: key === root.service.nextName
                    accent: Colours.palette.m3primary
                }
            }

                // ── Sunrise (display-only, between Fajr and Dhuhr) ────────────
            PrayerRow {
                visible: !root.showSettings && root.service.sunriseTime !== "" && root.service.prayers.length > 0
                prayerName: qsTr("Sunrise")
                prayerTime: root.service.sunriseTime
                prayerIcon: root.prayerIcons.Sunrise
                highlight: false
                dimmed: true
            }

                // ── Settings view (write-through: edits apply live and are saved
                // to mawaqit.json automatically) ──────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                // Fixed capped height: a fillHeight item inside this
                // height-less ColumnLayout would resolve to zero.
                implicitHeight: Math.min(settingsCol.implicitHeight, 460)
                visible: root.showSettings
                contentHeight: settingsCol.implicitHeight
                contentWidth: width
                flickableDirection: Flickable.VerticalFlick
                clip: true

                ColumnLayout {
                    id: settingsCol

                    width: parent.width
                    spacing: Tokens.spacing.small

                    component SectionLabel: StyledText {
                        Layout.topMargin: Tokens.spacing.small
                        text: "Section"
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.builders.large.build()
                    }

                    component SwitchRow: RowLayout {
                        id: switchRow

                        required property string label
                        property alias checked: toggle.checked
                        signal toggled(check: bool)

                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: switchRow.label
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledSwitch {
                            id: toggle

                            onToggled: switchRow.toggled(checked)
                        }
                    }

                    // Dropdown picker over all installed font families, with
                    // search and per-family preview. Emits picked(family).
                    component FontSelector: ColumnLayout {
                        id: selector

                        required property string title
                        required property string value
                        required property string placeholder
                        signal picked(family: string)

                        property bool expanded: false
                        property string query: ""

                        readonly property var matches: {
                            const q = selector.query.trim().toLowerCase();
                            const all = root.systemFonts;
                            const out = [];
                            for (let i = 0; i < all.length; i++) {
                                if (q === "" || all[i].toLowerCase().indexOf(q) !== -1)
                                    out.push(all[i]);
                                if (out.length >= 30)
                                    break;
                            }
                            return out;
                        }

                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        TextButton {
                            Layout.fillWidth: true
                            text: selector.title + ": " + (selector.value !== "" ? selector.value : selector.placeholder)
                            onClicked: selector.expanded = !selector.expanded
                        }

                        StyledTextField {
                            Layout.fillWidth: true
                            visible: selector.expanded
                            placeholderText: qsTr("Search %1 fonts…").arg(root.systemFonts.length)
                            onTextEdited: selector.query = text
                        }

                        Flickable {
                            Layout.fillWidth: true
                            implicitHeight: Math.min(listCol.implicitHeight, 190)
                            visible: selector.expanded
                            contentHeight: listCol.implicitHeight
                            contentWidth: width
                            flickableDirection: Flickable.VerticalFlick
                            clip: true

                            ColumnLayout {
                                id: listCol

                                width: parent.width
                                spacing: 0

                                TextButton {
                                    Layout.fillWidth: true
                                    isToggle: true
                                    checked: selector.value === ""
                                    text: selector.placeholder
                                    onClicked: selector.picked("")
                                }

                                Repeater {
                                    model: selector.matches

                                    delegate: TextButton {
                                        required property string modelData

                                        Layout.fillWidth: true
                                        isToggle: true
                                        checked: modelData === selector.value
                                        text: modelData
                                        font: Qt.font({ family: modelData, pointSize: Tokens.font.body.medium.pointSize })
                                        onClicked: selector.picked(modelData)
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel {
                        text: qsTr("Location")
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        text: root.service.city
                        placeholderText: qsTr("City")
                        supportingText: qsTr("English city name")
                        onTextEdited: root.service.city = text
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        text: root.service.country
                        placeholderText: qsTr("Country")
                        supportingText: qsTr("Country name or 2-letter code")
                        onTextEdited: root.service.country = text
                    }

                    SectionLabel {
                        text: qsTr("Calculation")
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        text: root.service.method
                        placeholderText: "3"
                        supportingText: qsTr("3 MWL · 4 Makkah · 5 Egypt · 21 Morocco · 99 custom")
                        inputMethodHints: Qt.ImhDigitsOnly
                        onTextEdited: root.service.method = text
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Asr school")
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        TextButton {
                            isToggle: true
                            checked: root.service.school === "0"
                            text: qsTr("Shafi")
                            onClicked: root.service.school = "0"
                        }

                        TextButton {
                            isToggle: true
                            checked: root.service.school === "1"
                            text: qsTr("Hanafi")
                            onClicked: root.service.school = "1"
                        }
                    }

                    SwitchRow {
                        label: qsTr("12-hour clock")
                        checked: root.service.twelveHourFormat
                        onToggled: check => root.service.twelveHourFormat = check
                    }

                    SectionLabel {
                        text: qsTr("Fonts")
                    }

                    FontSelector {
                        id: latinFontSel

                        title: qsTr("Latin font")
                        placeholder: qsTr("Theme default")
                        value: root.service.fontFamily
                        onPicked: fam => {
                            root.service.fontFamily = fam;
                            latinFontSel.expanded = false;
                        }
                    }

                    FontSelector {
                        id: arabicFontSel

                        title: qsTr("Arabic font")
                        placeholder: qsTr("Same as Latin")
                        value: root.service.arabicFontFamily
                        onPicked: fam => {
                            root.service.arabicFontFamily = fam;
                            arabicFontSel.expanded = false;
                        }
                    }

                    SectionLabel {
                        text: qsTr("Alerts")
                    }

                    SwitchRow {
                        label: qsTr("Notifications")
                        checked: root.service.showNotifications
                        onToggled: check => root.service.showNotifications = check
                    }

                    SwitchRow {
                        label: qsTr("Play azan")
                        checked: root.service.playAzan
                        onToggled: check => root.service.playAzan = check
                    }

                    StyledTextField {
                        Layout.fillWidth: true
                        visible: root.service.playAzan
                        text: root.service.azanPath
                        placeholderText: "~/.config/caelestia/mawaqit-azan.mp3"
                        supportingText: qsTr("Azan audio file (needs paplay or pw-cat)")
                        onTextEdited: root.service.azanPath = text
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.small
                        text: qsTr("Changes apply live and are saved to mawaqit.json automatically.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                }
            }
            }
        }
    }
    }

    // ── Single prayer row ─────────────────────────────────────────────
    component PrayerRow: StyledRect {
        id: row

        required property string prayerName
        required property string prayerTime
        required property string prayerIcon
        property bool highlight: false
        property bool dimmed: false
        property color accent: Colours.palette.m3primary

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + Tokens.padding.small * 2

        radius: Tokens.rounding.medium
        color: row.highlight ? Colours.tPalette.m3surfaceContainer : "transparent"

        RowLayout {
            id: rowLayout

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: row.prayerIcon
                color: row.highlight ? row.accent : (row.dimmed ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface)
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: row.prayerName
                color: row.highlight ? row.accent : (row.dimmed ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface)
                font: root.themedFont(row.highlight ? Tokens.font.body.builders.medium.weight(Font.Medium).build() : Tokens.font.body.medium, root.service.fontFamily)
                elide: Text.ElideRight
            }

            StyledText {
                animate: true
                text: row.prayerTime
                color: row.highlight ? row.accent : Colours.palette.m3onSurfaceVariant
                font: root.themedFont(row.highlight ? Tokens.font.body.builders.medium.weight(Font.Medium).build() : Tokens.font.body.medium, root.service.fontFamily)
            }
        }
    }
}
