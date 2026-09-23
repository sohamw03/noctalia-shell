import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI

PanelWindow {
  id: root

  property ShellScreen screen

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
  readonly property bool isFramed: Settings.data.bar.barType === "framed"
  readonly property bool barFloating: Settings.data.bar.barType === "floating"
  readonly property real barMarginH: barFloating ? Math.ceil(Settings.data.bar.marginHorizontal) : 0
  readonly property real barMarginV: barFloating ? Math.ceil(Settings.data.bar.marginVertical) : 0
  readonly property real barHeight: Style.getBarHeightForScreen(screen?.name)
  readonly property real cornerInset: barFloating ? Style.radiusL : 0
  readonly property bool barHidden: BarService.isBarHidden(screen?.name)

  color: "transparent"
  mask: Region {}
  visible: BarService.effectivelyVisible && !barHidden && !isFramed

  WlrLayershell.namespace: "noctalia-bar-highlight-" + (screen?.name || "unknown")
  WlrLayershell.layer: BarService.fullscreenOverlayActive ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  anchors {
    top: barPosition === "top" || barIsVertical
    bottom: barPosition === "bottom" || barIsVertical
    left: barPosition === "left" || !barIsVertical
    right: barPosition === "right" || !barIsVertical
  }

  margins {
    top: barPosition === "top" ? barMarginV : barMarginV
    bottom: barPosition === "bottom" ? barMarginV : barMarginV
    left: barPosition === "left" ? barMarginH : barMarginH
    right: barPosition === "right" ? barMarginH : barMarginH
  }

  implicitWidth: barIsVertical ? barHeight : screen.width
  implicitHeight: barIsVertical ? screen.height : barHeight

  Rectangle {
    anchors.fill: parent
    color: "transparent"

    // Windows-style light catches the edge facing the desktop content.
    Rectangle {
      id: highlight
      visible: root.visible
      color: Qt.alpha("#ffffff", 0.14)
      antialiasing: false

      x: {
        if (root.barIsVertical)
          return root.barPosition === "left" ? root.width - 1 : 0;
        return root.cornerInset;
      }
      y: {
        if (root.barIsVertical)
          return root.cornerInset;
        return root.barPosition === "bottom" ? 0 : root.height - 1;
      }
      width: root.barIsVertical ? 1 : Math.max(0, root.width - root.cornerInset * 2)
      height: root.barIsVertical ? Math.max(0, root.height - root.cornerInset * 2) : 1
    }
  }
}
