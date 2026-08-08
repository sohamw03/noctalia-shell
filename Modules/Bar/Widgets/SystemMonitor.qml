import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen
  property bool hoverHold: false

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property bool compactMode: widgetSettings.compactMode !== undefined ? widgetSettings.compactMode : widgetMetadata.compactMode
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : widgetMetadata.textColor

  readonly property bool useMonospaceFont: widgetSettings.useMonospaceFont !== undefined ? widgetSettings.useMonospaceFont : widgetMetadata.useMonospaceFont
  readonly property bool usePadding: !compactMode && !isVertical && useMonospaceFont && ((widgetSettings.usePadding !== undefined) ? widgetSettings.usePadding : widgetMetadata.usePadding)

  readonly property bool showCpuUsage: (widgetSettings.showCpuUsage !== undefined) ? widgetSettings.showCpuUsage : widgetMetadata.showCpuUsage
  readonly property bool showCpuCores: (widgetSettings.showCpuCores !== undefined) ? widgetSettings.showCpuCores : widgetMetadata.showCpuCores
  readonly property bool showCpuFreq: (widgetSettings.showCpuFreq !== undefined) ? widgetSettings.showCpuFreq : widgetMetadata.showCpuFreq
  readonly property bool showCpuTemp: (widgetSettings.showCpuTemp !== undefined) ? widgetSettings.showCpuTemp : widgetMetadata.showCpuTemp
  readonly property bool showGpuTemp: (widgetSettings.showGpuTemp !== undefined) ? widgetSettings.showGpuTemp : widgetMetadata.showGpuTemp
  readonly property bool showMemoryUsage: (widgetSettings.showMemoryUsage !== undefined) ? widgetSettings.showMemoryUsage : widgetMetadata.showMemoryUsage
  readonly property bool showMemoryAsPercent: (widgetSettings.showMemoryAsPercent !== undefined) ? widgetSettings.showMemoryAsPercent : widgetMetadata.showMemoryAsPercent
  readonly property bool showSwapUsage: (widgetSettings.showSwapUsage !== undefined) ? widgetSettings.showSwapUsage : widgetMetadata.showSwapUsage
  readonly property bool showNetworkStats: (widgetSettings.showNetworkStats !== undefined) ? widgetSettings.showNetworkStats : widgetMetadata.showNetworkStats
  readonly property bool showDiskUsage: (widgetSettings.showDiskUsage !== undefined) ? widgetSettings.showDiskUsage : widgetMetadata.showDiskUsage
  readonly property bool showDiskUsageAsPercent: (widgetSettings.showDiskUsageAsPercent !== undefined) ? widgetSettings.showDiskUsageAsPercent : widgetMetadata.showDiskUsageAsPercent
  readonly property bool showDiskAvailable: (widgetSettings.showDiskAvailable !== undefined) ? widgetSettings.showDiskAvailable : widgetMetadata.showDiskAvailable
  readonly property bool showLoadAverage: (widgetSettings.showLoadAverage !== undefined) ? widgetSettings.showLoadAverage : widgetMetadata.showLoadAverage
  readonly property string diskPath: (widgetSettings.diskPath !== undefined) ? widgetSettings.diskPath : widgetMetadata.diskPath
  readonly property string fontFamily: useMonospaceFont ? Settings.data.ui.fontFixed : Settings.data.ui.fontDefault

  readonly property int paddingPercent: usePadding ? String("100%").length : 0
  readonly property int paddingTemp: usePadding ? String("999°").length : 0
  readonly property int paddingCpuFreq: usePadding ? String("9.9").length : 0
  readonly property int paddingSpeed: usePadding ? String("9999G").length : 0

  readonly property real iconSize: Style.toOdd(capsuleHeight * 0.48)
  readonly property real miniGaugeWidth: Math.max(3, Style.toOdd(root.iconSize * 0.25))

  // Content dimensions for implicit sizing
  readonly property real contentWidth: isVertical ? capsuleHeight : Math.round(mainGrid.implicitWidth + Style.margin2M)
  readonly property real contentHeight: isVertical ? Math.round(mainGrid.implicitHeight + Style.margin2M) : capsuleHeight

  readonly property color iconColor: Color.resolveColorKey(iconColorKey)
  readonly property color textColor: Color.resolveColorKey(textColorKey)

  // Size: use implicit width/height
  // BarWidgetLoader sets explicit width/height to extend click area
  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Component.onCompleted: SystemStatService.registerComponent("bar-sysmon:" + (screen?.name || "unknown"))
  Component.onDestruction: SystemStatService.unregisterComponent("bar-sysmon:" + (screen?.name || "unknown"))

  function openExternalMonitor() {
    Quickshell.execDetached(["sh", "-c", Settings.data.systemMonitor.externalMonitor]);
  }

  function hoverForeground(color, preserveStatusColor = false) {
    return preserveStatusColor || !(tooltipArea.containsMouse || hoverHold) ? color : Color.mOnHover;
  }

  // Build comprehensive tooltip text with all stats
  function buildTooltipContent() {
    let rows = [];
    let metrics = [];

    function addPair(icon1, label1, val1, icon2, label2, val2) {
      rows.push([
        icon1 || "", label1 || "", val1 || "",
        icon2 || "", label2 || "", val2 || ""
      ]);
    }

    // CPU Usage & Frequency
    metrics.push({
      icon: "cpu-usage",
      label: I18n.tr("system-monitor.cpu-usage"),
      value: `${Math.round(SystemStatService.cpuUsage)}% (${SystemStatService.cpuFreq.replace(/[^0-9.]/g, "")} GHz)`
    });

    // CPU Temp (if available)
    if (SystemStatService.cpuTemp > 0) {
      metrics.push({
        icon: "cpu-temperature",
        label: I18n.tr("system-monitor.cpu-temp"),
        value: `${Math.round(SystemStatService.cpuTemp)}°C`
      });
    }



    // Memory — used / total
    metrics.push({
      icon: "memory",
      label: I18n.tr("common.memory"),
      value: `${(SystemStatService.memGb).toFixed(1)} / ${(SystemStatService.memTotalGb).toFixed(1)} GiB`
    });


    // Disk — used / total
    const diskPercent = SystemStatService.diskPercents[diskPath];
    if (diskPercent !== undefined) {
      const usedGb = SystemStatService.diskUsedGb[diskPath] || 0;
      const sizeGb = SystemStatService.diskSizeGb[diskPath] || 0;

      metrics.push({
        icon: "storage",
        label: I18n.tr("system-monitor.disk"),
        value: `${usedGb.toFixed(1)} / ${sizeGb.toFixed(1)} GB`
      });
    }

    // Network Download
    metrics.push({
      icon: "download-speed",
      label: I18n.tr("system-monitor.download-speed"),
      value: `${SystemStatService.formatSpeed(SystemStatService.rxSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2")}/s`
    });

    // Network Upload
    metrics.push({
      icon: "upload-speed",
      label: I18n.tr("system-monitor.upload-speed"),
      value: `${SystemStatService.formatSpeed(SystemStatService.txSpeed).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2")}/s`
    });

    // GPU Temp (if available) — last left column
    if (SystemStatService.gpuAvailable) {
      metrics.push({
        icon: "gpu-temperature",
        label: I18n.tr("system-monitor.gpu-temp"),
        value: `${Math.round(SystemStatService.gpuTemp)}°C`
      });
    }

    // Pair metrics into 6-column rows
    for (let i = 0; i < metrics.length; i += 2) {
      const m1 = metrics[i];
      const m2 = metrics[i + 1];
      if (m2) {
        addPair(m1.icon, m1.label, m1.value, m2.icon, m2.label, m2.value);
      } else {
        addPair(m1.icon, m1.label, m1.value, "", "", "");
      }
    }

    // CPU Cores (if enabled) - paired side-by-side
    if (showCpuCores && SystemStatService.coresUsage && SystemStatService.coresUsage.length > 0) {
      const cores = SystemStatService.coresUsage;
      for (let c = 0; c < cores.length; c += 2) {
        const label1 = I18n.tr("system-monitor.core-usage", { "id": c });
        const val1 = `${Math.round(cores[c])}%`;
        let label2 = "";
        let val2 = "";
        if (c + 1 < cores.length) {
          label2 = I18n.tr("system-monitor.core-usage", { "id": c + 1 });
          val2 = `${Math.round(cores[c + 1])}%`;
        }
        addPair("", label1, val1, "", label2, val2);
      }
    }

    return rows;
  }

  // Visibility-aware warning/critical states (delegates to service)
  readonly property bool cpuWarning: showCpuUsage && SystemStatService.cpuWarning
  readonly property bool cpuCritical: showCpuUsage && SystemStatService.cpuCritical
  readonly property bool tempWarning: showCpuTemp && SystemStatService.tempWarning
  readonly property bool tempCritical: showCpuTemp && SystemStatService.tempCritical
  readonly property bool gpuWarning: showGpuTemp && SystemStatService.gpuWarning
  readonly property bool gpuCritical: showGpuTemp && SystemStatService.gpuCritical
  readonly property bool memWarning: showMemoryUsage && SystemStatService.memWarning
  readonly property bool memCritical: showMemoryUsage && SystemStatService.memCritical
  readonly property bool swapWarning: showSwapUsage && SystemStatService.swapWarning
  readonly property bool swapCritical: showSwapUsage && SystemStatService.swapCritical
  readonly property bool diskWarning: showDiskUsage && SystemStatService.isDiskWarning(diskPath)
  readonly property bool diskCritical: showDiskUsage && SystemStatService.isDiskCritical(diskPath)

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": I18n.tr("system-monitor.title"),
        "action": "sysmon-settings",
        "icon": "settings"
      },
      {
        "label": I18n.tr("actions.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "sysmon-settings") {
                     let monitorCmd = Settings.data.systemMonitor.externalMonitor;
                     if (monitorCmd && monitorCmd.trim() !== "") {
                       openExternalMonitor();
                     } else {
                       SettingsPanelService.openToTab(SettingsPanel.Tab.System, 0, screen);
                     }
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  // Visual capsule centered in parent
  Rectangle {
    id: visualCapsule
    width: root.contentWidth
    height: root.contentHeight
    anchors.centerIn: parent
    radius: Style.radiusM
    color: tooltipArea.pressed ? Color.mHoverPressed : ((tooltipArea.containsMouse || root.hoverHold) ? Color.mHover : Style.capsuleColor)
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // Mini gauge component for compact mode, vertical gauge that fills from bottom
    Component {
      id: miniGaugeComponent

      NLinearGauge {
        ratio: 0
        orientation: Qt.Vertical
        fillColor: Color.mPrimary
        width: miniGaugeWidth
        height: iconSize
      }
    }

    GridLayout {
      id: mainGrid
      anchors.centerIn: parent
      flow: isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
      rows: isVertical ? -1 : 1
      columns: isVertical ? 1 : -1
      rowSpacing: isVertical ? (compactMode ? Style.marginL : Style.marginXL) : 0
      columnSpacing: isVertical ? 0 : Style.marginM

      // CPU Usage Component
      Item {
        id: cpuUsageContainer
        implicitWidth: cpuUsageContent.implicitWidth
        implicitHeight: cpuUsageContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showCpuUsage

        GridLayout {
          id: cpuUsageContent
          anchors.centerIn: parent

          property bool verticalDisplay: isVertical && (!compactMode || showCpuCores)
          flow: verticalDisplay ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: verticalDisplay ? -1 : 1
          columns: verticalDisplay ? 1 : -1
          rowSpacing: compactMode ? 3 : Style.marginXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "cpu-usage"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground((cpuWarning || cpuCritical) ? SystemStatService.cpuColor : root.iconColor, cpuWarning || cpuCritical)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: `${Math.round(SystemStatService.cpuUsage)}%`.padStart(paddingPercent, " ")
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground((cpuWarning || cpuCritical) ? SystemStatService.cpuColor : root.textColor, cpuWarning || cpuCritical)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode general cpu
          Loader {
            active: compactMode && !showCpuCores
            visible: compactMode && !showCpuCores
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.cpuUsage / 100);
              item.fillColor = Qt.binding(() => SystemStatService.cpuColor);
            }
          }

          // Compact mode for cores
          Repeater {
            model: (compactMode && showCpuCores) ? SystemStatService.coresUsage : []

            delegate: NLinearGauge {
              required property var modelData
              width: isVertical ? iconSize : miniGaugeWidth
              height: isVertical ? miniGaugeWidth : iconSize
              orientation: isVertical ? Qt.Horizontal : Qt.Vertical
              ratio: modelData / 100
              fillColor: SystemStatService.getCoreUsageColor(modelData)
            }
          }
        }
      }

      // CPU Frequency Component
      Item {
        id: cpuFreqContainer
        implicitWidth: cpuFreqContent.implicitWidth
        implicitHeight: cpuFreqContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showCpuFreq && (!isVertical || compactMode)

        GridLayout {
          id: cpuFreqContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "cpu-usage"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground(root.iconColor)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: SystemStatService.cpuFreq.replace("Hz", "").replace(" ", "").padStart(paddingCpuFreq, " ")
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground(root.textColor)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.cpuFreqRatio);
            }
          }
        }
      }

      // CPU Temperature Component
      Item {
        id: cpuTempContainer
        implicitWidth: cpuTempContent.implicitWidth
        implicitHeight: cpuTempContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showCpuTemp

        GridLayout {
          id: cpuTempContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "cpu-temperature"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground((tempWarning || tempCritical) ? SystemStatService.tempColor : root.iconColor, tempWarning || tempCritical)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: `${Math.round(SystemStatService.cpuTemp)}°`.padStart(paddingTemp, " ")
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground((tempWarning || tempCritical) ? SystemStatService.tempColor : root.textColor, tempWarning || tempCritical)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode, mini gauge (to the right of icon)
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.cpuTemp / 100);
              item.fillColor = Qt.binding(() => SystemStatService.tempColor);
            }
          }
        }
      }

      // GPU Temperature Component
      Item {
        id: gpuTempContainer
        implicitWidth: gpuTempContent.implicitWidth
        implicitHeight: gpuTempContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showGpuTemp && SystemStatService.gpuAvailable

        GridLayout {
          id: gpuTempContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "gpu-temperature"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground((gpuWarning || gpuCritical) ? SystemStatService.gpuColor : root.iconColor, gpuWarning || gpuCritical)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: `${Math.round(SystemStatService.gpuTemp)}°`.padStart(paddingTemp, " ")
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground((gpuWarning || gpuCritical) ? SystemStatService.gpuColor : root.textColor, gpuWarning || gpuCritical)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.gpuTemp / 100);
              item.fillColor = Qt.binding(() => SystemStatService.gpuColor);
            }
          }
        }
      }

      // Load Average Component
      Item {
        id: loadAvgContainer
        implicitWidth: loadAvgContent.implicitWidth
        implicitHeight: loadAvgContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showLoadAverage && SystemStatService.nproc > 0 && SystemStatService.loadAvg1 > 0

        GridLayout {
          id: loadAvgContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "weight"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground(root.iconColor)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: `${SystemStatService.loadAvg1.toFixed(1)}`.padStart(usePadding ? `${SystemStatService.nproc.toFixed(1)}`.length : 0, " ")
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground(root.textColor)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => Math.min(1, SystemStatService.loadAvg1 / SystemStatService.nproc));
            }
          }
        }
      }

      // Memory Usage Component
      Item {
        id: memoryContainer
        implicitWidth: memoryContent.implicitWidth
        implicitHeight: memoryContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showMemoryUsage

        GridLayout {
          id: memoryContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "memory"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground((memWarning || memCritical) ? SystemStatService.memColor : root.iconColor, memWarning || memCritical)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: SystemStatService.formatRamDisplay({
                                                       percent: showMemoryAsPercent,
                                                       padding: usePadding
                                                     })
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground((memWarning || memCritical) ? SystemStatService.memColor : root.textColor, memWarning || memCritical)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.memPercent / 100);
              item.fillColor = Qt.binding(() => SystemStatService.memColor);
            }
          }
        }
      }

      // Swap Usage Component
      Item {
        id: swapContainer
        implicitWidth: swapContent.implicitWidth
        implicitHeight: swapContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showSwapUsage && SystemStatService.swapTotalGb > 0

        GridLayout {
          id: swapContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "exchange"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground((swapWarning || swapCritical) ? SystemStatService.swapColor : root.iconColor, swapWarning || swapCritical)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: SystemStatService.formatRamDisplay({
                                                       swap: true,
                                                       percent: true,
                                                       padding: usePadding
                                                     })
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground((swapWarning || swapCritical) ? SystemStatService.swapColor : root.textColor, swapWarning || swapCritical)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.swapPercent / 100);
              item.fillColor = Qt.binding(() => SystemStatService.swapColor);
            }
          }
        }
      }

      // Network Download Speed Component
      Item {
        implicitWidth: downloadContent.implicitWidth
        implicitHeight: downloadContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showNetworkStats

        GridLayout {
          id: downloadContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "download-speed"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground(root.iconColor)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: isVertical ? SystemStatService.formatCompactSpeed(SystemStatService.rxSpeed) : SystemStatService.formatSpeed(SystemStatService.rxSpeed).padStart(paddingSpeed, " ")
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground(root.textColor)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.rxRatio);
            }
          }
        }
      }

      // Network Upload Speed Component
      Item {
        implicitWidth: uploadContent.implicitWidth
        implicitHeight: uploadContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showNetworkStats

        GridLayout {
          id: uploadContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "upload-speed"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground(root.iconColor)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: isVertical ? SystemStatService.formatCompactSpeed(SystemStatService.txSpeed) : SystemStatService.formatSpeed(SystemStatService.txSpeed).padStart(paddingSpeed, " ")
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground(root.textColor)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => SystemStatService.txRatio);
            }
          }
        }
      }

      // Disk Usage Component (primary drive)
      Item {
        id: diskContainer
        implicitWidth: diskContent.implicitWidth
        implicitHeight: diskContent.implicitHeight
        Layout.preferredWidth: isVertical ? root.width : implicitWidth
        Layout.preferredHeight: compactMode ? implicitHeight : capsuleHeight
        Layout.alignment: isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: showDiskUsage

        GridLayout {
          id: diskContent
          anchors.centerIn: parent
          flow: (isVertical && !compactMode) ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rows: (isVertical && !compactMode) ? 2 : 1
          columns: (isVertical && !compactMode) ? 1 : 2
          rowSpacing: Style.marginXXS
          columnSpacing: compactMode ? 3 : Style.marginXS

          Item {
            Layout.preferredWidth: iconSize
            Layout.preferredHeight: (compactMode || isVertical) ? iconSize : capsuleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.row: (isVertical && !compactMode) ? 1 : 0
            Layout.column: 0

            NIcon {
              icon: "storage"
              pointSize: iconSize
              applyUiScale: false
              x: Style.pixelAlignCenter(parent.width, width)
              y: Style.pixelAlignCenter(parent.height, contentHeight)
              color: root.hoverForeground((diskWarning || diskCritical) ? SystemStatService.getDiskColor(diskPath) : root.iconColor, diskWarning || diskCritical)
            }
          }

          // Text mode
          NText {
            visible: !compactMode
            text: SystemStatService.formatDiskDisplay(diskPath, {
                                                        percent: showDiskUsageAsPercent,
                                                        available: showDiskAvailable,
                                                        padding: usePadding
                                                      })
            family: fontFamily
            pointSize: barFontSize
            applyUiScale: false
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.hoverForeground((diskWarning || diskCritical) ? SystemStatService.getDiskColor(diskPath) : root.textColor, diskWarning || diskCritical)
            Layout.row: isVertical ? 0 : 0
            Layout.column: isVertical ? 0 : 1
          }

          // Compact mode
          Loader {
            active: compactMode
            visible: compactMode
            sourceComponent: miniGaugeComponent
            Layout.alignment: Qt.AlignCenter
            Layout.row: 0
            Layout.column: 1

            onLoaded: {
              item.ratio = Qt.binding(() => (showDiskAvailable ? SystemStatService.diskAvailPercents[diskPath] : SystemStatService.diskPercents[diskPath] ?? 0) / 100);
              item.fillColor = Qt.binding(() => SystemStatService.getDiskColor(diskPath, showDiskAvailable));
            }
          }
        }
      }
    }
  }

  // MouseArea at root level for extended click area
  MouseArea {
    id: tooltipArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    onClicked: mouse => {
                 root.hoverHold = true;
                 hoverHoldTimer.restart();
                 if (mouse.button === Qt.LeftButton) {
                   PanelService.getPanel("systemStatsPanel", screen)?.toggle(root);
                   TooltipService.hide();
                 } else if (mouse.button === Qt.RightButton) {
                   TooltipService.hide();
                   PanelService.showContextMenu(contextMenu, root, screen);
                 } else if (mouse.button === Qt.MiddleButton) {
                   TooltipService.hide();
                   openExternalMonitor();
                 }
    }
    onEntered: {
      hoverHoldTimer.stop();
      root.hoverHold = false;
      if (!PanelService.getPanel("systemStatsPanel", screen).isPanelOpen) {
        TooltipService.show(root, buildTooltipContent(), BarService.getTooltipDirection(root.screen?.name));
        tooltipRefreshTimer.start();
      }
    }
    onExited: {
      tooltipRefreshTimer.stop();
      TooltipService.hide();
    }
  }

  Timer {
    id: hoverHoldTimer
    interval: Style.animationNormal + 50
    onTriggered: root.hoverHold = false
  }

  Timer {
    id: tooltipRefreshTimer
    interval: 1000
    repeat: true
    onTriggered: {
      if (tooltipArea.containsMouse) {
        TooltipService.updateText(buildTooltipContent());
      }
    }
  }
}
