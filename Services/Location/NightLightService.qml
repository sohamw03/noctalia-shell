pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.UI

Singleton {
  id: root

  // Night Light properties - directly bound to settings
  readonly property var params: Settings.data.nightLight

  // Generated shader lives in the shell cache dir and is rewritten
  // whenever the night temperature changes.
  readonly property string shaderPath: Settings.cacheDir + "noctalia-nightlight.glsl"

  // Tracks what we last asked hyprshade to do, so re-applying the same
  // state doesn't recompile the shader (visible flicker) for nothing.
  property bool shadeOn: false
  property int lastTemp: -1
  property bool autoWarned: false

  // One-time migration: kill orphans of the old wlsunset backend.
  // (wlsunset can't drive gamma on Hyprland, but strays may linger.)
  Component.onCompleted: {
    cleanupOldBackend.running = true;
  }

  Process {
    id: cleanupOldBackend
    running: false
    command: ["sh", "-c", "pkill -x wlsunset 2>/dev/null; exit 0"]
    onExited: root.apply()
  }

  // One-shot runner: hyprshade applies instantly and exits, the compositor
  // holds the shader. There is no daemon to supervise.
  Process {
    id: shadeRunner
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function (code) {
      if (code !== 0) {
        Logger.e("NightLight", "hyprshade failed (code " + code + "):", stderr.text);
        // Forget last intent so the next apply() retries instead of
        // assuming the shader is on.
        root.shadeOn = false;
        root.lastTemp = -1;
      }
    }
  }

  Timer {
    id: manualScheduleTimer
    repeat: false
    onTriggered: {
      Logger.i("NightLight", "Manual schedule: phase boundary reached");
      root.applyManualSchedule();
    }
  }

  function timeToMinutes(timeStr) {
    var parts = timeStr.split(":").map(Number);
    return parts[0] * 60 + parts[1];
  }

  function isManualMode() {
    return !params.forced && !params.autoSchedule;
  }

  function nightTemp() {
    var t = parseInt(params.nightTemp);
    if (isNaN(t)) {
      t = 4500;
    }
    return Math.min(6500, Math.max(1000, t));
  }

  function isCurrentlyNight() {
    var now = new Date();
    var nowMin = now.getHours() * 60 + now.getMinutes();
    var sunsetMin = timeToMinutes(params.manualSunset);
    var sunriseMin = timeToMinutes(params.manualSunrise);

    if (sunsetMin < sunriseMin) {
      // Inverted: e.g. sunset=03:00, sunrise=07:00 → night is [03:00, 07:00)
      return nowMin >= sunsetMin && nowMin < sunriseMin;
    } else {
      // Normal: e.g. sunset=18:00, sunrise=06:00 → night is [18:00, 06:00)
      return nowMin >= sunsetMin || nowMin < sunriseMin;
    }
  }

  function msUntilNextBoundary() {
    var now = new Date();
    var nowMin = now.getHours() * 60 + now.getMinutes();
    var sunsetMin = timeToMinutes(params.manualSunset);
    var sunriseMin = timeToMinutes(params.manualSunrise);

    var targetMin = isCurrentlyNight() ? sunriseMin : sunsetMin;
    var diffMin = targetMin - nowMin;
    if (diffMin <= 0)
      diffMin += 1440;

    return diffMin * 60 * 1000 - now.getSeconds() * 1000 - now.getMilliseconds();
  }

  // Tanner Helland approximation of black-body white point.
  // Returns [r, g, b] multipliers in 0..1 for the given kelvin.
  function kelvinToRgb(kelvin) {
    var t = kelvin / 100.0;
    var r, g, b;
    if (t <= 66) {
      r = 255;
    } else {
      r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
    }
    if (t <= 66) {
      g = 99.4708025861 * Math.log(t) - 161.1195681661;
    } else {
      g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
    }
    if (t >= 66) {
      b = 255;
    } else if (t <= 19) {
      b = 0;
    } else {
      b = 138.5177312231 * Math.log(t - 10) - 305.0447927307;
    }
    function cl(v) {
      return Math.min(1, Math.max(0, v / 255));
    }
    return [cl(r), cl(g), cl(b)];
  }

  // Fresh blue-light-filter screen shader with the white point for temp
  // baked in, plus ordered dithering so crushing blue doesn't band.
  function buildShader(temp) {
    var rgb = kelvinToRgb(temp);
    var r = rgb[0].toFixed(4);
    var g = rgb[1].toFixed(4);
    var b = rgb[2].toFixed(4);
    return ["#version 320 es", "precision highp float;", "", "in vec2 v_texcoord;", "uniform sampler2D tex;", "out vec4 fragColor;", "", "// Night light white point for " + temp + "K (Tanner Helland approximation)", "const vec3 kWhitePoint = vec3(" + r + ", " + g + ", " + b + ");", "", "// Compact 4x4 Bayer ordered dither: hides banding after the warm", "// multiply crushes the blue channel.", "float bayer2(vec2 a) {", "  a = floor(a);", "  return fract(a.x / 2.0 + a.y * a.y * 0.75);", "}", "", "float bayer4(vec2 a) {", "  return bayer2(0.5 * a) * 0.25 + bayer2(a);", "}", "", "void main() {", "  vec4 color = texture(tex, v_texcoord);", "  color.rgb *= kWhitePoint;", "  color.rgb += (bayer4(gl_FragCoord.xy) - 0.5) * (1.5 / 255.0);", "  fragColor = color;", "}"].join("\n");
  }

  // Drive hyprshade to the desired state. Writes the shader file and
  // applies it in a single one-shot process invocation.
  function setShader(on, temp) {
    if (!ProgramCheckerService.hyprshadeAvailable) {
      Logger.w("NightLight", "hyprshade not available, cannot apply night light");
      return;
    }
    if (!on) {
      if (!root.shadeOn) {
        return;
      }
      root.shadeOn = false;
      root.lastTemp = -1;
      shadeRunner.command = ["hyprshade", "off"];
      shadeRunner.running = true;
      Logger.i("NightLight", "Shader off");
      return;
    }
    if (root.shadeOn && root.lastTemp === temp) {
      return;
    }
    root.shadeOn = true;
    root.lastTemp = temp;
    var script = "cat > '" + root.shaderPath + "' <<'NOCTALIA_NL_EOF'\n" + buildShader(temp) + "\nNOCTALIA_NL_EOF\nhyprshade on '" + root.shaderPath + "'";
    shadeRunner.command = ["sh", "-c", script];
    shadeRunner.running = true;
    Logger.i("NightLight", "Shader on (" + temp + "K)");
  }

  function applyManualSchedule() {
    if (!params.enabled) {
      manualScheduleTimer.stop();
      setShader(false, 0);
      return;
    }

    if (isCurrentlyNight()) {
      setShader(true, nightTemp());
      Logger.i("NightLight", "Manual schedule: night phase");
    } else {
      setShader(false, 0);
      Logger.i("NightLight", "Manual schedule: day phase");
    }

    var ms = msUntilNextBoundary();
    manualScheduleTimer.interval = Math.max(ms, 1000);
    manualScheduleTimer.restart();
    Logger.i("NightLight", "Manual schedule: next boundary in " + Math.round(ms / 1000) + "s");
  }

  function apply(force = false) {
    if (force) {
      // Bypass the same-state dedup below (resume / retry paths).
      root.shadeOn = false;
      root.lastTemp = -1;
    }

    // If using LocationService, wait for it to be ready
    if (!params.forced && params.autoSchedule && !LocationService.coordinatesReady) {
      return;
    }

    // Manual mode: handle scheduling ourselves
    if (isManualMode() && params.enabled) {
      applyManualSchedule();
      return;
    }

    // Not in manual mode - clean up manual timer
    manualScheduleTimer.stop();

    if (params.autoSchedule) {
      // hyprshade has no solar computation; stay off rather than tinting
      // at the wrong time of day.
      if (params.enabled && !root.autoWarned) {
        root.autoWarned = true;
        Logger.w("NightLight", "Solar auto-schedule is not supported by the hyprshade backend yet - use manual times or forced mode");
      }
      setShader(false, 0);
      return;
    }

    // Forced mode (or disabled): shader on at night temp, off otherwise.
    setShader(params.enabled, nightTemp());
  }

  // Observe setting changes and location readiness
  Connections {
    target: Settings.data.nightLight
    function onEnabledChanged() {
      apply();
      // Toast: night light toggled
      const enabled = !!Settings.data.nightLight.enabled;
      ToastService.showNotice(I18n.tr("common.night-light"), enabled ? I18n.tr("common.enabled") : I18n.tr("common.disabled"), enabled ? "nightlight-on" : "nightlight-off");
    }
    function onForcedChanged() {
      apply();
      if (Settings.data.nightLight.enabled) {
        ToastService.showNotice(I18n.tr("common.night-light"), Settings.data.nightLight.forced ? I18n.tr("toast.night-light.forced") : I18n.tr("toast.night-light.normal"), Settings.data.nightLight.forced ? "nightlight-forced" : "nightlight-on");
      }
    }
    function onNightTempChanged() {
      apply();
    }
    function onDayTempChanged() {
      apply();
    }
    function onManualSunriseChanged() {
      apply();
    }
    function onManualSunsetChanged() {
      apply();
    }
    function onAutoScheduleChanged() {
      apply();
    }
  }

  Connections {
    target: ProgramCheckerService
    function onHyprshadeAvailableChanged() {
      if (ProgramCheckerService.hyprshadeAvailable) {
        Logger.i("NightLight", "hyprshade became available - applying");
        root.apply();
      }
    }
  }

  Connections {
    target: LocationService
    function onCoordinatesReadyChanged() {
      if (LocationService.coordinatesReady) {
        root.apply();
      }
    }
  }

  Timer {
    id: resumeRetryTimer
    interval: 2000
    repeat: false
    onTriggered: {
      Logger.i("NightLight", "Resume retry - re-applying night light again");
      root.apply(true);
    }
  }

  Connections {
    target: Time
    function onResumed() {
      Logger.i("NightLight", "System resumed - re-applying night light");
      root.apply(true);
      resumeRetryTimer.restart();
    }
  }
}
