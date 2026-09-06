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
  property real minimumBarPx: 2 // Minimal visible extent in pixels

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
      property real effectiveAmp: (root.showMinimumSignal || root.randomize) ? Math.max(rawAmp, root.minimumSignalValue) : rawAmp
      property real rawBarSize: (vertical ? root.width : root.height) * effectiveAmp
      property real barSize: (root.showMinimumSignal || root.randomize) ? Math.max(root.minimumBarPx, rawBarSize) : rawBarSize

      // Equal integer width - all bars same, pixel-snapped sides
      readonly property int barWidthInt: Math.max(1, Math.round(root.barSlotSize * 0.8))

      color: root.fillColor
      border.color: root.strokeColor
      border.width: root.strokeWidth
      antialiasing: true
      smooth: false

      width: vertical ? barSize : barWidthInt
      height: vertical ? barWidthInt : barSize
      x: vertical ? root.centerX - (barSize / 2) : Math.round(index * root.barSlotSize + (root.barSlotSize - barWidthInt) / 2)
      y: vertical ? Math.round(index * root.barSlotSize + (root.barSlotSize - barWidthInt) / 2) : root.centerY - (barSize / 2)

      // Disable updates when invisible to save GPU
      visible: root.visible
    }
  }
}
