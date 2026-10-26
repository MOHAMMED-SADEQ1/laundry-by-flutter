import 'dart:io';

import 'package:laundry/services/i18n/translations_en.dart';

void main() {
  final re = RegExp(r"(?:tr|trf)\(\s*'([^'\n]*[\u0600-\u06FF][^'\n]*)'");
  final all = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('translations_en.dart')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      all.add(m.group(1)!);
    }
  }
  final missing = all.where((s) => !kEnglish.containsKey(s)).toList()
    ..sort();
  for (final s in missing) {
    print(s);
  }
  print('--- ${missing.length} missing of ${all.length} wrapped');
}
