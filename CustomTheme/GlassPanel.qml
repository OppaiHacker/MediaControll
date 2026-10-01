import QtQuick

// "Liquid glass" surface: a thin translucent tint over the compositor blur
// (Hyprland layer_rule blur on the quickshell:* namespaces), a top sheen, a
// specular rim along the upper edge and a soft accent glow along the bottom.
// Fill alpha must stay above the layer rule's ignore_alpha (0.3) or Hyprland
// skips the blur behind it.
Item {
    id: glass
    property real radius: 16
    property color tint: Theme.background
    property real tintAlpha: 0.42
    property color glow: Theme.primary

    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

        // Sheen: brighter at the top, a hint of the accent at the bottom.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.03) }
            GradientStop { position: 1.0; color: Qt.rgba(glass.glow.r, glass.glow.g, glass.glow.b, 0.10) }
        }
    }

    // Base tint under the sheen (a Rectangle can't take both color and gradient).
    Rectangle {
        anchors.fill: parent
        z: -1
        radius: glass.radius
        color: Qt.rgba(glass.tint.r, glass.tint.g, glass.tint.b, glass.tintAlpha)
    }

    // Specular rim along the top edge.
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * glass.radius
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.7) }
            GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.7) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    // Accent glow along the bottom edge.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * glass.radius
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(glass.glow.r, glass.glow.g, glass.glow.b, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(glass.glow.r, glass.glow.g, glass.glow.b, 0.8) }
            GradientStop { position: 1.0; color: Qt.rgba(glass.glow.r, glass.glow.g, glass.glow.b, 0) }
        }
    }
}
