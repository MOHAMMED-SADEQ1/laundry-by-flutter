import 'dart:io';

import 'package:laundry/services/i18n/translations_en.dart';

void main(List<String> args) {
  final only = args.isEmpty ? null : args.first;
  final re = RegExp(r"'([^'\n]*[\u0600-\u06FF][^'\n]*)'");
  final rows = <String, Set<String>>{};
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final path = f.path.replaceAll('\\', '/');
    if (path.contains('/i18n/')) continue;
    if (only != null && !path.contains(only)) continue;
    final missing = <String>{};
    for (final line in f.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in re.allMatches(line)) {
        final s = m.group(1)!;
        if (!kEnglish.containsKey(s)) missing.add(s);
      }
    }
    if (missing.isNotEmpty) rows[path] = missing;
  }
  final sorted = rows.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final e in sorted) {
    print('${e.value.length.toString().padLeft(4)}  ${e.key}');
    if (only != null) {
      final list = e.value.toList()..sort();
      for (final s in list) {
        print('    - $s');
      }
    }
  }
  print('--- ${sorted.length} files, '
      '${rows.values.fold<int>(0, (a, b) => a + b.length)} unique-file misses');
}
