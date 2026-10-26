import 'dart:io';

void main(List<String> args) {
  final only = args.isEmpty ? null : args.first;
  final re = RegExp(r"'([^'\n]*[\u0600-\u06FF][^'\n]*)'");
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final path = f.path.replaceAll('\\', '/');
    if (path.contains('/i18n/')) continue;
    if (only != null && !path.contains(only)) continue;
    var printed = false;
    final lines = f.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final t = line.trimLeft();
      if (t.startsWith('//')) continue;
      if (!re.hasMatch(line)) continue;
      if (line.contains('tr(') ||
          line.contains('trf(') ||
          line.contains('localized') ||
          line.contains('L10n.')) {
        continue;
      }
      if (!printed) {
        print('=== $path');
        printed = true;
      }
      print('${(i + 1).toString().padLeft(4)}: $t');
    }
  }
}
