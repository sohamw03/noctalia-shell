import QtQuick
import qs.Commons

Item {
  id: root
  property color fillColor: Color.mPrimary
  property color strokeColor: Color.mOnSurface
  property int strokeWidth: 0
  property var values: []
  property bool vertical: false
  property bool mirrored: true
  // Shuffle band order across bars so movement looks random instead of symmetric
  property bool randomize: false

  // Minimum signal properties
  property bool showMinimumSignal: false
  property real minimumSignalValue: 0.01 // Default to 1% of height

  // Pre-compute mirroring
  readonly property int valuesCount: (values && values.length !== undefined) ? values.length : 0
  readonly property int totalBars: (mirrored || randomize) ? valuesCount * 2 : valuesCount
  readonly property real barSlotSize: totalBars > 0 ? (vertical ? height : width) / totalBars : 0
  readonly property real centerY: height / 2
  readonly property real centerX: width / 2

  // Stable shuffled band order (each band used twice to match the mirrored
  // bar density), rebuilt only when the band count changes
  readonly property var bandOrder: randomize ? _shuffledIndices(valuesCount) : []

  function _shuffledIndices(n) {
    const indices = [];
    for (let i = 0; i < n; i++) {
      indices.push(i);
      indices.push(i);
    }
    for (let i = indices.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = indices[i];
      indices[i] = indices[j];
      indices[j] = tmp;
    }
    return indices;
  }

  Repeater {
    model: root.totalBars

    Rectangle {
      property int valueIndex: {
        if (root.randomize)
          return (root.bandOrder[index] !== undefined) ? root.bandOrder[index] : 0;
        return root.mirrored ? (index < root.valuesCount ? root.valuesCount - 1 - index : index - root.valuesCount) : index;
      }

      property real rawAmp: (root.values && root.values[valueIndex] !== undefined) ? root.values[valueIndex] : 0
      property real amp: (root.showMinimumSignal && rawAmp === 0) ? root.minimumSignalValue : rawAmp

      property real barSize: (vertical ? root.width : root.height) * amp

      // Pixel-snapped slots keep bar sides crisp; the amplitude length stays
      // continuous so bars grow smoothly (AA handles the sub-pixel tips)
      readonly property int slotStart: Math.round(index * root.barSlotSize)
      readonly property int slotEnd: Math.round((index + 1) * root.barSlotSize)
      readonly property int slotPx: Math.max(1, slotEnd - slotStart)

      color: root.fillColor
      border.color: root.strokeColor
      border.width: root.strokeWidth
      antialiasing: true
      smooth: false

      width: vertical ? barSize : Math.max(1, Math.round(slotPx * 0.8))
      height: vertical ? Math.max(1, Math.round(slotPx * 0.8)) : barSize
      x: vertical ? root.centerX - (barSize / 2) : slotStart + Math.floor((slotPx - width) / 2)
      y: vertical ? slotStart + Math.floor((slotPx - height) / 2) : root.centerY - (barSize / 2)

      // Disable updates when invisible to save GPU
      visible: root.visible
    }
  }
}
