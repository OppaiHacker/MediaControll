import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.CustomTheme

// Now-playing capsule for the bar. Hovering it morphs a "dynamic island" out
// of the capsule with the blurred cover as its background and playback controls.
Item {
    id: media

    // The playing player wins; otherwise the first one (e.g. a paused tab).
    readonly property MprisPlayer player: {
        const ps = Mpris.players.values
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null
    }
    readonly property bool collapsed: player === null
    readonly property bool playing: player?.isPlaying ?? false
    property bool focused: false

    readonly property string url: player?.metadata["xesam:url"] ?? ""
    readonly property string ytId: {
        const m = url.match(/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|embed\/|live\/)|youtu\.be\/)([\w-]{11})/)
        return m ? m[1] : ""
    }
    // Player-provided art first. YouTube in Firefox often sends none, so build
    // the thumbnail from the video id: maxres (or the portrait one for shorts),
    // falling back to mqdefault, which always exists and has no letterbox bars.
    readonly property string primaryArt: player?.trackArtUrl ? player.trackArtUrl
        : ytId === "" ? ""
        : "https://i.ytimg.com/vi/" + ytId + (url.includes("/shorts/") ? "/oardefault.jpg" : "/maxresdefault.jpg")
    readonly property string art: probe.status === Image.Error && ytId !== ""
        ? "https://i.ytimg.com/vi/" + ytId + "/mqdefault.jpg"
        : primaryArt

    readonly property string appName: ytId !== "" || url.includes("youtube.com") ? "YouTube"
        : player?.identity ?? ""
    readonly property string appGlyph: {
        const n = appName.toLowerCase()
        return String.fromCodePoint(n.includes("youtube") ? 0xF16A
            : n.includes("spotify") ? 0xF1BC
            : n.includes("firefox") ? 0xF269
            : 0xF075A)
    }
    readonly property string glyphFont: "FiraCode Nerd Font"

    function activate(): void { player?.togglePlaying() }

    // Volume of the player's own audio streams (matched by app name, e.g.
    // desktop entry "zen" -> stream "Zen"/"zen-bin"); the default sink when the
    // player has no stream right now.
    readonly property string appKey: (player?.desktopEntry || player?.identity || "").toLowerCase()
    readonly property var streams: appKey === "" ? [] : Pipewire.nodes.values.filter(n =>
        n.isStream && n.audio && n.isSink
        && [n.name, n.properties["application.name"], n.properties["application.process.binary"]]
            .some(v => (v ?? "").toLowerCase().includes(appKey)))
    readonly property var volTargets: streams.length > 0 ? streams
        : Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    readonly property real volume: volTargets[0]?.audio?.muted ? 0 : (volTargets[0]?.audio?.volume ?? 0)
    PwObjectTracker { objects: media.volTargets }

    function setVolume(v: real): void {
        v = Math.max(0, Math.min(1, v))
        for (const t of volTargets) {
            if (!t.audio)
                continue
            t.audio.muted = false
            t.audio.volume = v
        }
    }

    function toggleMute(): void {
        const m = !(volTargets[0]?.audio?.muted ?? false)
        for (const t of volTargets)
            if (t.audio)
                t.audio.muted = m
    }

    function fmt(s: real): string {
        s = Math.max(0, Math.floor(s))
        const sec = s % 60
        return Math.floor(s / 60) + ":" + (sec < 10 ? "0" : "") + sec
    }

    visible: !collapsed
    implicitWidth: collapsed ? 0 : mini.implicitWidth + 20
    implicitHeight: 30

    // Only used to detect a missing maxres/oar thumbnail.
    Image { id: probe; visible: false; source: media.primaryArt; sourceSize.width: 32 }

    // ==========================================
    // REUSABLE PIECES
    // ==========================================

    // Cropped, heavily blurred cover used as a background.
    component BlurArt: Item {
        id: ba
        // Darkening at top / bottom, and color strength of the blurred cover.
        property real dimTop: 0.25
        property real dimBottom: 0.55
        property real saturation: 0.35
        property real brightness: -0.08
        property int blurMax: 64
        clip: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.primary_container }
                GradientStop { position: 1; color: Theme.surface }
            }
        }
        Image {
            id: bgImg
            // Oversized so the blur's soft edges fall outside the clip.
            anchors.centerIn: parent
            width: parent.width * 1.4
            height: parent.height * 1.4
            source: media.art
            sourceSize.width: 256
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: bgImg
            source: bgImg
            visible: bgImg.status === Image.Ready
            blurEnabled: true
            blur: 1.0
            blurMax: ba.blurMax
            saturation: ba.saturation
            brightness: ba.brightness
        }
        // Darken for legible white text.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, ba.dimTop) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, ba.dimBottom) }
            }
        }
    }

    component Cover: ClippingRectangle {
        color: Qt.rgba(1, 1, 1, 0.08)
        Text {
            anchors.centerIn: parent
            visible: coverImg.status !== Image.Ready
            text: media.appGlyph
            color: "white"
            font.family: media.glyphFont
            font.pixelSize: parent.height * 0.5
        }
        Image {
            id: coverImg
            anchors.fill: parent
            source: media.art
            sourceSize.width: 256
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }

    // Three bouncing bars, frozen while paused.
    component Equalizer: Row {
        id: eq
        property real barHeight: 14
        property color barColor: "white"
        spacing: 2
        Repeater {
            model: [0.55, 0.9, 0.7]
            Rectangle {
                required property real modelData
                required property int index
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                color: eq.barColor
                height: eq.barHeight * 0.3
                SequentialAnimation on height {
                    running: media.playing
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    PauseAnimation { duration: index * 90 }
                    NumberAnimation { to: eq.barHeight * modelData; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                    NumberAnimation { to: eq.barHeight * 0.3; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                }
            }
        }
        height: barHeight
    }

    component MiniRow: RowLayout {
        spacing: 8
        Cover {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            radius: 11
        }
        Text {
            Layout.maximumWidth: 200
            text: media.player?.trackTitle || media.appName
            elide: Text.ElideRight
            color: "white"
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
        Equalizer {
            barHeight: 12
            opacity: media.playing ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string glyph
        property real size: 40
        property real glyphSize: 22
        property bool filled: false
        signal clicked()
        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: filled ? Qt.rgba(1, 1, 1, ibMouse.containsMouse ? 1 : 0.92)
            : Qt.rgba(1, 1, 1, ibMouse.containsMouse ? 0.18 : 0)
        scale: ibMouse.pressed ? 0.86 : 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        Text {
            anchors.centerIn: parent
            text: ib.glyph
            color: ib.filled ? "black" : "white"
            font.family: media.glyphFont
            font.pixelSize: ib.glyphSize
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    // ==========================================
    // BAR CAPSULE
    // ==========================================
    ClippingRectangle {
        id: capsule
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        // Vivid blurred cover; the small capsule needs less blur and dimming
        // than the island or the colors wash out.
        BlurArt {
            anchors.fill: parent
            saturation: 0.9
            brightness: 0.0
            blurMax: 24
            dimTop: 0.2
            dimBottom: 0.4
        }
        GlassPanel {
            anchors.fill: parent
            radius: capsule.radius
            tintAlpha: 0
        }
        Rectangle {
            anchors.fill: parent
            radius: capsule.radius
            color: "transparent"
            border.color: Theme.primary
            border.width: 1
            opacity: media.focused ? 1 : 0
        }
        MiniRow {
            id: mini
            anchors.centerIn: parent
        }
    }

    HoverHandler { id: capsuleHover }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => e.button === Qt.RightButton ? media.player?.next()
            : e.button === Qt.MiddleButton ? media.player?.previous()
            : media.activate()
    }

    // ==========================================
    // DYNAMIC ISLAND
    // ==========================================
    // Open while the capsule or the island is hovered; the close is debounced
    // so the pointer can cross from the bar surface onto the popup surface.
    readonly property bool wantOpen: !collapsed && (capsuleHover.hovered || islandHover.hovered || seekArea.pressed || volArea.pressed)
    property bool open: false
    onWantOpenChanged: wantOpen ? (closeTimer.stop(), openTimer.restart()) : (openTimer.stop(), closeTimer.restart())
    Timer { id: openTimer; interval: 120; onTriggered: media.open = true }
    Timer { id: closeTimer; interval: 260; onTriggered: media.open = false }

    readonly property int islandW: 420
    readonly property int islandH: 222
    readonly property int shadowPad: 30

    PopupWindow {
        id: popup
        anchor.item: media
        anchor.rect.x: media.width / 2 - popup.implicitWidth / 2
        anchor.rect.y: 0
        anchor.rect.width: popup.implicitWidth
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: media.islandW + 2 * media.shadowPad
        implicitHeight: media.islandH + media.shadowPad
        color: "transparent"
        // Stay mapped until the shrink animation has finished.
        visible: media.open || island.width > media.width + 1
        mask: Region { item: island }

        RectangularShadow {
            anchors.fill: island
            radius: island.radius
            blur: 30
            spread: -4
            offset.y: 8
            color: Qt.rgba(0, 0, 0, 0.55 * island.progress)
        }

        ClippingRectangle {
            id: island
            readonly property bool expanded: media.open && popup.visible
            // 0 = capsule, 1 = fully open; drives every crossfade.
            readonly property real progress: Math.max(0, Math.min(1,
                (height - media.height) / (media.islandH - media.height)))

            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: expanded ? media.islandW : media.width
            height: expanded ? media.islandH : media.height
            radius: Math.min(height / 2, 34)
            color: "transparent"

            Behavior on width { SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.5 } }
            Behavior on height { SpringAnimation { spring: 3.2; damping: 0.3; epsilon: 0.5 } }

            HoverHandler { id: islandHover }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => media.setVolume(media.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))
            }

            // Fixed size so the blur renders once, not every animation frame;
            // the liquid glass below refracts it into the morphing island.
            BlurArt {
                id: islandArt
                anchors.centerIn: parent
                width: media.islandW
                height: media.islandH
            }
            ShaderEffectSource {
                id: islandArtSrc
                sourceItem: islandArt
                hideSource: true
                width: 0; height: 0
            }
            LiquidGlass {
                anchors.fill: parent
                radius: island.radius
                source: islandArtSrc
                origin: Qt.point(-islandArt.x, -islandArt.y)
                backdropSize: Qt.size(media.islandW, media.islandH)
                tintAmount: 0.12
                strength: 18
                bezel: 22
                blurRadius: 3
            }

            // Capsule look-alike so the morph starts seamlessly from the bar.
            MiniRow {
                anchors.centerIn: parent
                opacity: Math.max(0, 1 - island.progress * 3)
                visible: opacity > 0
            }

            // ---------- expanded content ----------
            Item {
                id: content
                width: media.islandW
                height: media.islandH
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: Math.max(0, (island.progress - 0.45) / 0.55)
                visible: opacity > 0
                scale: 0.9 + 0.1 * island.progress
                transformOrigin: Item.Top

                // Cover + text
                Cover {
                    id: bigCover
                    x: 22; y: 22
                    width: 76; height: 76
                    radius: 16
                    scale: media.playing ? 1 : 0.9
                    Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                }

                Column {
                    anchors.left: bigCover.right
                    anchors.leftMargin: 16
                    anchors.right: eqBig.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: bigCover.verticalCenter
                    spacing: 3

                    Text {
                        text: media.appGlyph + "  " + media.appName
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.family: media.glyphFont
                        font.pixelSize: 11
                    }

                    // Marquee title when it does not fit.
                    Item {
                        width: parent.width
                        height: titleText.implicitHeight
                        clip: true
                        Text {
                            id: titleText
                            readonly property real overflow: implicitWidth - parent.width
                            text: media.player?.trackTitle || "Unknown"
                            color: "white"
                            font.family: Theme.fontFamily
                            font.pixelSize: 17
                            font.bold: true
                            x: 0
                            SequentialAnimation on x {
                                running: titleText.overflow > 0 && content.visible
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) titleText.x = 0
                                PauseAnimation { duration: 1800 }
                                NumberAnimation { to: -titleText.overflow; duration: Math.max(1, titleText.overflow * 28); easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 1200 }
                                NumberAnimation { to: 0; duration: Math.max(1, titleText.overflow * 28); easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: media.player?.trackArtist ?? ""
                        visible: text !== ""
                        elide: Text.ElideRight
                        color: Qt.rgba(1, 1, 1, 0.72)
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                Equalizer {
                    id: eqBig
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.top: bigCover.top
                    anchors.topMargin: 4
                    barHeight: 18
                    barColor: Theme.primary
                }

                // Progress
                Item {
                    id: progressRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    y: 112
                    height: 16
                    visible: (media.player?.length ?? 0) > 0

                    readonly property real len: media.player?.length ?? 0
                    readonly property real frac: len > 0 ? Math.min(1, (media.player?.position ?? 0) / len) : 0

                    Text {
                        id: posText
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        text: media.fmt(media.player?.position ?? 0)
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        id: lenText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        horizontalAlignment: Text.AlignRight
                        text: media.fmt(progressRow.len)
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Rectangle {
                        id: track
                        anchors.left: posText.right
                        anchors.right: lenText.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: seekArea.containsMouse || seekArea.pressed ? 8 : 5
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.22)
                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                        Rectangle {
                            width: Math.max(parent.height, parent.width * (seekArea.pressed ? Math.max(0, Math.min(1, (seekArea.mouseX - 8) / track.width)) : progressRow.frac))
                            height: parent.height
                            radius: parent.radius
                            color: "white"
                            Behavior on width { enabled: !seekArea.pressed; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            id: seekArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            enabled: media.player?.canSeek ?? false
                            cursorShape: Qt.PointingHandCursor
                            onReleased: media.player.position = Math.max(0, Math.min(1, (mouseX - 8) / track.width)) * progressRow.len
                        }
                    }

                    // Position is not pushed by MPRIS; poll it while visible.
                    Timer {
                        running: content.visible && media.playing
                        interval: 500
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: media.player?.positionChanged()
                    }
                }

                // Controls
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 136
                    spacing: 22
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: String.fromCodePoint(0xF04AE)
                        opacity: media.player?.canGoPrevious ?? false ? 1 : 0.35
                        onClicked: media.player?.previous()
                    }
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 46
                        glyphSize: 24
                        filled: true
                        glyph: String.fromCodePoint(media.playing ? 0xF03E4 : 0xF040A)
                        onClicked: media.activate()
                    }
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: String.fromCodePoint(0xF04AD)
                        opacity: media.player?.canGoNext ?? false ? 1 : 0.35
                        onClicked: media.player?.next()
                    }
                }

                // Volume
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    height: 20

                    Text {
                        id: volIcon
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        text: String.fromCodePoint(media.volume <= 0 ? 0xF0581 : media.volume < 0.4 ? 0xF057F : media.volume < 0.75 ? 0xF0580 : 0xF057E)
                        color: Qt.rgba(1, 1, 1, volIconMouse.containsMouse ? 1 : 0.7)
                        font.family: media.glyphFont
                        font.pixelSize: 16
                        MouseArea {
                            id: volIconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: media.toggleMute()
                        }
                    }
                    Text {
                        id: volText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(media.volume * 100) + "%"
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Rectangle {
                        id: volTrack
                        anchors.left: volIcon.right
                        anchors.right: volText.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: volArea.containsMouse || volArea.pressed ? 8 : 5
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.22)
                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                        Rectangle {
                            width: Math.max(parent.height, parent.width * Math.min(1, media.volume))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                            Behavior on width { enabled: !volArea.pressed; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            id: volArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            function apply(): void { media.setVolume((mouseX - 8) / volTrack.width) }
                            onPressed: apply()
                            onPositionChanged: if (pressed) apply()
                        }
                    }
                }
            }
        }
    }
}
