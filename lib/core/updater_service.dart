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
///   1. download the ZIP into a temp staging dir,
///   2. extract it in Dart and stage all new files next to the exe,
///   3. write a tiny relaunch.bat that (after the app exits) copies staged files
///      over the running install and starts the new exe.
///
/// On web this only reports the update (no self-replace possible).
class UpdaterService {
  static const repo = 'https://api.github.com/repos/kotvhapke/Squall/releases/latest';
  static const _assetName = 'squall-windows.zip';

  static Future<UpdateInfo> checkForUpdate({String currentVersion = '1.1.9'}) async {
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

  /// Downloads the ZIP, extracts and stages new files, returns a relaunch bat path.
  static Future<String> prepareUpdate(String url, {required void Function(double) onProgress}) async {
    if (kIsWeb) {
      throw UnsupportedError('Web cannot self-update. Use Ctrl+F5.');
    }
    final installDir = File(Platform.resolvedExecutable).parent;
    final zipBytes = <int>[];

    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Download failed (${response.statusCode})');
    }
    final total = response.contentLength ?? 0;
    await response.stream.forEach((chunk) {
      zipBytes.addAll(chunk);
      if (total > 0) onProgress(zipBytes.length / total);
    });

    // Stage dir for the extracted zip
    final staging = Directory('${installDir.path}\\squall-update-staging');
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);

    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      final safe = name.contains('..') ? name.split('/').where((s) => s != '..').join('/') : name;
      final out = File('${staging.path}\\$safe');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(f.content, flush: true);
    }

    // Locate squall.exe inside staging (may be nested)
    final exeName = Platform.resolvedExecutable.split('\\').last;
    final foundExe = _findFile(staging.path, exeName) ?? _findFile(staging.path, 'squall.exe');
    if (foundExe == null) {
      staging.deleteSync(recursive: true);
      throw Exception('Could not locate squall.exe in the downloaded archive');
    }
    final exeSourceDir = File(foundExe).parent;

    // Write a relaunch bat. It runs AFTER the app exits: copies staged files
    // over the current install dir, then starts the new exe.
    final batPath = '${installDir.path}\\squall-relaunch.bat';
    final bat = '''
@echo off
setlocal
cd /d "%~dp0"
timeout /t 2 /nobreak >nul
taskkill /f /im "$exeName" >nul 2>&1
timeout /t 1 /nobreak >nul
echo [!] Installing Squall update...
:: Copy new exe first (only remove old if copy succeeded)
if not exist "$exeSourceDir\\$exeName" (
  echo [!] New exe not found in staging. Aborting.
  pause
  exit /b 1
)
copy /y "$exeSourceDir\\$exeName" "%~dp0$exeName" >nul 2>&1
if not exist "%~dp0$exeName" (
  echo [!] Failed to copy new exe. Aborting.
  pause
  exit /b 1
)
:: Copy data outright (overwrite)
if exist "$exeSourceDir\\data" xcopy /e /i /q /y "$exeSourceDir\\data" "%~dp0data\\" >nul 2>&1
:: Copy any dlls
for /r "$exeSourceDir" %%f in (*.dll) do copy /y "%%f" "%~dp0" >nul 2>&1
:: Clean up staging
if exist "%~dp0squall-update-staging" rmdir /s /q "%~dp0squall-update-staging"
echo [!] Done. Launching Squall...
cd /d "%~dp0"
start "" "%~dp0$exeName"
exit
''';
    File(batPath).writeAsStringSync(bat, flush: true);
    return batPath;
  }

  static String? _findFile(String dir, String name) {
    try {
      for (final e in Directory(dir).listSync(recursive: true)) {
        if (e is File && e.path.split(Platform.pathSeparator).last == name) {
          return e.path;
        }
      }
    } catch (_) {}
    return null;
  }

  static void runAndExit(String batPath) {
    Process.start('cmd', ['/c', 'start', '', batPath]);
  }
}
