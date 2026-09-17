import 'dart:io';
import 'package:flutter/foundation.dart';

/// Creates a Windows desktop shortcut for the running Squall executable.
/// If a shortcut already exists but points to a different exe (e.g. after
/// extracting a new version into a new folder), it updates the target.
/// Runs on non-web platforms only; no-op elsewhere.
class ShortcutService {
  static Future<void> ensureDesktopShortcut() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final exePath = Platform.resolvedExecutable;
      final desktop = _desktopPath();
      if (desktop == null) return;
      final lnk = '$desktop\\Squall.lnk';

      final script = _ps(exePath, lnk);
      await Process.run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script]);
    } catch (_) {}
  }

  static String? _desktopPath() {
    // Use known-folder via PS for reliability.
    try {
      final r = Process.runSync('powershell', [
        '-NoProfile', '-Command',
        "[Environment]::GetFolderPath('Desktop')",
      ]);
      final p = (r.stdout as String).trim();
      return p.isEmpty ? null : p;
    } catch (_) {
      return null;
    }
  }

  static String _ps(String exe, String lnk) {
    final e = exe.replaceAll("'", "''");
    final l = lnk.replaceAll("'", "''");
    final wd = Directory(exe).parent.path.replaceAll("'", "''");
    return "\$s = New-Object -ComObject WScript.Shell; "
        "\$sc = \$s.CreateShortcut('$l'); "
        "if (\$sc.TargetPath -ne '$e') { "
        "\$sc.TargetPath = '$e'; "
        "\$sc.WorkingDirectory = '$wd'; "
        "\$sc.IconLocation = '$e,0'; "
        "\$sc.Save(); }";
  }
}
