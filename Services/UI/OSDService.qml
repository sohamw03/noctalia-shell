pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  // Generic one-shot text popup on the centered OSD (capslock-style box).
  // Trigger from anywhere: qs -p <shell> ipc call osd showText "some text" "icon-name"
  // Held popup (strict hold until explicitly hidden):
  //   qs -p <shell> ipc call osd showHold "Opening ..." "icon-name"
  //   qs -p <shell> ipc call osd hide
  signal customRequested(string text, string icon, bool hold)
  signal customHideRequested

  function show(text, icon = "") {
    customRequested(text || "", icon || "", false);
  }

  function showHold(text, icon = "") {
    customRequested(text || "", icon || "", true);
  }

  function hide() {
    customHideRequested();
  }
}
