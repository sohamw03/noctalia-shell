import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v60 (enable Custom OSD text type)");

    const rawTypes = rawJson?.osd?.enabledTypes;
    if (!Array.isArray(rawTypes)) {
      logger.d("Migration60", "No osd.enabledTypes array found, skipping migration");
      return true;
    }

    if (rawTypes.includes(4)) {
      logger.d("Migration60", "Custom OSD type already enabled, skipping migration");
      return true;
    }

    adapter.osd.enabledTypes = [...rawTypes, 4];
    logger.i("Migration60", "Enabled Custom OSD text type (appended 4 to osd.enabledTypes)");

    return true;
  }
}
