import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Visual values must come from trosky_ui's tokens. This fails when Dart
/// code anywhere in apps/ or packages/ (outside lib/src/tokens) writes a raw
/// colour or font size.
final _rules = <String, RegExp>{
  'Color(0x…)': RegExp(r'\bColor\(\s*0x'),
  'Color.fromARGB / fromRGBO': RegExp(r'\bColor\.from(ARGB|RGBO)\('),
  'Colors.*': RegExp(r'\bColors\.'),
  'raw fontSize': RegExp(r'\bfontSize:\s*-?[\d.]'),
};

List<String> _violations(String path, List<String> lines) {
  final found = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    for (final rule in _rules.entries) {
      if (rule.value.hasMatch(line)) {
        found.add('$path:${i + 1}  ${rule.key}  ${line.trim()}');
      }
    }
  }
  return found;
}

void main() {
  test('no raw colours or font sizes outside trosky_ui tokens', () {
    // Tests run from packages/trosky_ui; the workspace root is two levels up.
    final root = Directory('../..').absolute;
    final violations = <String>[];
    for (final top in ['apps', 'packages']) {
      final files = Directory('${root.path}/$top')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.contains('/.dart_tool/') ||
            path.contains('/build/') ||
            path.contains('/packages/trosky_ui/lib/src/tokens/') ||
            path.endsWith('/packages/trosky_ui/test/token_guard_test.dart')) {
          continue;
        }
        violations.addAll(_violations(path, file.readAsLinesSync()));
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the rules catch each kind of raw value', () {
    const samples = [
      'color: Color(0xFF0E9E6D),',
      'color: Color.fromARGB(255, 14, 158, 109),',
      'color: Colors.white,',
      'style: TextStyle(fontSize: 14),',
    ];
    for (final sample in samples) {
      expect(_violations('sample', [sample]), hasLength(1), reason: sample);
    }
    expect(_violations('ok', ['color: TroskyColors.white,']), isEmpty);
    expect(_violations('ok', ['// Colors.white in a comment']), isEmpty);
  });
}
