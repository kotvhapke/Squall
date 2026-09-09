import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final bool available;
  final String url;
  final String? notes;

  const UpdateInfo({required this.version, required this.available, required this.url, this.notes});
}

/// Self-updater for Squall.
///
/// On Windows the running .exe cannot be overwritten while it is running, so we:
///   1. download the ZIP into the install dir,
///   2. write a small update.bat that copies the new files over the app and
///      relaunches it,
///   3. tell the caller to exit the app — the bat takes over.
///
/// On web this only reports the update (no self-replace possible).
class UpdaterService {
  static const repo = 'https://api.github.com/repos/kotvhapke/Squall/releases/latest';
  static const _assetName = 'squall-windows.zip';

  static Future<UpdateInfo> checkForUpdate({String currentVersion = '1.1.2'}) async {
    try {
      final res = await http.get(Uri.parse(repo), headers: {'Accept': 'application/vnd.github+json'});
      if (res.statusCode != 200) {
        return UpdateInfo(version: currentVersion, available: false, url: '');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final version = (data['tag_name'] as String? ?? '').replaceAll('v', '');
      final notes = data['body'] as String?;
      final assetUrl = _findAsset(data);
      return UpdateInfo(version: version, available: _isNewer(version, currentVersion), url: assetUrl, notes: notes);
    } catch (_) {
      return UpdateInfo(version: currentVersion, available: false, url: '');
    }
  }

  static String _findAsset(Map<String, dynamic> release) {
    final assets = release['assets'] as List? ?? [];
    for (final a in assets) {
      if (a is Map && a['name'] == _assetName) {
        return a['browser_download_url'] as String? ?? '';
      }
    }
    return '';
  }

  static bool _isNewer(String incoming, String current) {
    final a = incoming.split('.').map(int.tryParse).toList();
    final b = current.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? (a[i] ?? 0) : 0;
      final y = i < b.length ? (b[i] ?? 0) : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Downloads the ZIP, stages it next to the exe and prepares a relaunch script.
  /// Returns the path of the update.bat that must be executed AFTER the app exits.
  static Future<String> prepareUpdate(String url, {required void Function(double) onProgress}) async {
    if (kIsWeb) {
      throw UnsupportedError('Web cannot self-update. Use Ctrl+F5.');
    }
    final installDir = File(Platform.resolvedExecutable).parent;
    final zipPath = '${installDir.path}\\squall-update.zip';

    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }
    final total = response.contentLength ?? 0;
    final bytes = <int>[];
    await response.stream.forEach((chunk) {
      bytes.addAll(chunk);
      if (total > 0) {
        onProgress(bytes.length / total);
      }
    });
    File(zipPath).writeAsBytesSync(bytes, flush: true);

    final exePath = Platform.resolvedExecutable;
    final exeName = exePath.split('\\').last;
    final batPath = '${installDir.path}\\squall-update.bat';
    final bat = '''
@echo off
setlocal
cd /d "%~dp0"
timeout /t 1 /nobreak >nul
echo [!] Updating Squall... do not close this window.
if exist squall.exe del /f /q squall.exe
if exist *.dll del /f /q *.dll >nul 2>&1
if exist data rmdir /s /q data
powershell -NoProfile -Command "Expand-Archive -Path '%~dp0squall-update.zip' -DestinationPath '%~dp0' -Force" >nul 2>&1
if not exist squall.exe (
  :: fallback: unzip manually
  powershell -NoProfile -Command "Expand-Archive -Path '%~dp0squall-update.zip' -DestinationPath '%~dp0release' -Force" >nul 2>&1
  if exist "%~dp0release\\$exeName" copy /y "%~dp0release\\$exeName" "%~dp0$exeName" >nul
)
del /f /q "%~dp0squall-update.zip" >nul 2>&1
del /f /q "%~dp0squall-update.bat" >nul 2>&1
echo [!] Done. Launching Squall...
start "" "%~dp0$exeName"
exit
''';
    File(batPath).writeAsStringSync(bat, flush: true);
    return batPath;
  }

  /// Runs the update script detached (returns immediately).
  static void runAndExit(String batPath) {
    Process.start('cmd', ['/c', 'start', '"Squall Update"', batPath]);
    // Caller should now exit the app.
  }
}
