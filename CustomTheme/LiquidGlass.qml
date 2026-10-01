import QtQuick

// True liquid glass: a shader that lenses the backdrop at the rounded edge,
// splits it into RGB, softens and tints it, and lights a specular rim.
//
// Default backdrop is the current wallpaper laid out like awww does (cover),
// which is exactly what sits behind the bar and dock since windows never tile
// under them. Pass `source` (a texture provider, e.g. ShaderEffectSource) to
// refract something else.
Item {
    id: g

    property real radius: 16
    // Where this panel's top-left sits in backdrop pixels (screen coordinates
    // for the wallpaper) and the backdrop's size.
    property point origin: Qt.point(0, 0)
    property size backdropSize: Qt.size(1, 1)
    property var source: wallSource

    property real bezel: 16
    property real strength: 12
    property real aberration: 0.4
    property real blurRadius: 5
    property color tint: Theme.background
    property real tintAmount: 0.38
    property real specular: 0.55

    readonly property bool useWallpaper: source === wallSource

    Image {
        id: wall
        width: g.backdropSize.width
        height: g.backdropSize.height
        source: g.useWallpaper ? Theme.wallpaper : ""
        sourceSize.width: g.backdropSize.width
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    ShaderEffectSource {
        id: wallSource
        sourceItem: g.useWallpaper ? wall : null
        hideSource: true
        live: false
        recursive: false
        width: 0; height: 0
        // Re-grab once when the wallpaper finishes loading.
        Connections {
            target: wall
            function onStatusChanged() { if (wall.status === Image.Ready) wallSource.scheduleUpdate() }
        }
    }

    ShaderEffect {
        anchors.fill: parent
        property var backdrop: g.source
        property size size: Qt.size(width, height)
        property point origin: g.origin
        property size backdropSize: g.backdropSize
        property real radius: g.radius
        property real bezel: g.bezel
        property real strength: g.strength
        property real aberration: g.aberration
        property real blurRadius: g.blurRadius
        property vector4d tint: Qt.vector4d(g.tint.r, g.tint.g, g.tint.b, g.tintAmount)
        property real specular: g.specular
        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")
    }
}
