pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  // Generic one-shot text popup on the centered OSD (capslock-style box).
  // Trigger from anywhere: qs -p <shell> ipc call osd showText "some text" "icon-name"
  signal customRequested(string text, string icon)

  function show(text, icon = "") {
    customRequested(text || "", icon || "");
  }
}
