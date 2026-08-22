import QtQuick
import qs.Commons

Item {
  id: root
  property color fillColor: Color.mPrimary
  property color strokeColor: Color.mOnSurface
  property int strokeWidth: 0
  property var values: []
  property bool vertical: false
  property string barPosition: "top" // "top", "bottom", "left", "right"
  property bool mirrored: true

  // Minimum signal properties
  property bool showMinimumSignal: false
  property real minimumSignalValue: 0.01 // Default to 1% of height

  // Pre compute horizontal mirroring
  readonly property int valuesCount: (values && values.length !== undefined) ? values.length : 0
  readonly property int totalBars: mirrored ? valuesCount * 2 : valuesCount
  readonly property real barSlotSize: totalBars > 0 ? (vertical ? height : width) / totalBars : 0

  Repeater {
    model: root.totalBars

    Rectangle {
      property int valueIndex: root.mirrored ? (index < root.valuesCount ? root.valuesCount - 1 - index : index - root.valuesCount) : index

      property real rawAmp: (root.values && root.values[valueIndex] !== undefined) ? root.values[valueIndex] : 0
      property real amp: (root.showMinimumSignal && rawAmp === 0) ? root.minimumSignalValue : rawAmp

      // Pixel-snapped slots keep bar sides crisp; the amplitude length stays
      // continuous so bars grow smoothly (AA handles the sub-pixel tip)
      readonly property int slotStart: Math.round(index * root.barSlotSize)
      readonly property int slotEnd: Math.round((index + 1) * root.barSlotSize)
      readonly property int slotPx: Math.max(1, slotEnd - slotStart)
      readonly property real ampLen: (vertical ? root.width : root.height) * amp

      color: root.fillColor
      border.color: root.strokeColor
      border.width: root.strokeWidth
      antialiasing: true
      smooth: false

      // Only update when value actually changes - reduces GPU load
      width: vertical ? ampLen : Math.max(1, Math.round(slotPx * 0.5))
      height: vertical ? Math.max(1, Math.round(slotPx * 0.5)) : ampLen
      x: vertical ? (root.barPosition === "left" ? 0 : Math.ceil(root.width) - width) : slotStart + Math.floor((slotPx - width) / 2)
      y: vertical ? slotStart + Math.floor((slotPx - height) / 2) : Math.ceil(root.height) - height

      // Disable updates when invisible to save GPU
      visible: root.visible
    }
  }
}
