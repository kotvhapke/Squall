import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  final url = 'https://api.github.com/repos/kotvhapke/Squall/releases/latest';
  final res = await http.get(Uri.parse(url), headers: {'Accept': 'application/vnd.github+json'});
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final version = (data['tag_name'] as String? ?? '').replaceAll('v', '');
  final assets = data['assets'] as List? ?? [];
  String assetUrl = '';
  for (final a in assets) {
    if (a is Map && a['name'] == 'squall-windows.zip') assetUrl = a['browser_download_url'] ?? '';
  }
  print('latest version: $version');
  print('asset url: $assetUrl');
  print('is 1.1.3 newer than 1.1.2? ${_isNewer("1.1.3", "1.1.2")}');
  print('is 1.1.2 newer than 1.1.3? ${_isNewer("1.1.2", "1.1.3")}');
}

bool _isNewer(String incoming, String current) {
  final a = incoming.split('.').map(int.tryParse).toList();
  final b = current.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? (a[i] ?? 0) : 0;
    final y = i < b.length ? (b[i] ?? 0) : 0;
    if (x != y) return x > y;
  }
  return false;
}
