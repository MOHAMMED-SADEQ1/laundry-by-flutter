import 'dart:io';
import 'package:laundry/services/i18n/translations_en.dart';

void main() {
  final call = RegExp(r"(?:tr|trf)\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)");
  final lit = RegExp(r"'((?:[^'\\]|\\.)*)'");
  final all = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('translations_en.dart')) continue;
    for (final m in call.allMatches(f.readAsStringSync())) {
      final parts = lit.allMatches(m.group(1)!).map((x) => x.group(1)!);
      final key = parts.join().replaceAll(r"\'", "'").replaceAll(r'\\', r'\');
      all.add(key);
    }
  }
  final missing = all.where((s) => !kEnglish.containsKey(s)).toList()..sort();
  for (final s in missing) {
    print(s);
  }
  print('--- ${missing.length} missing of ${all.length} wrapped');
}
