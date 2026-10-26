import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/settings/setting_option.dart';

void main() {
  final seen = <String>{};
  for (final o in SettingOptions.all) {
    for (final s in [o.label, o.description, ...?o.choiceLabels?.values]) {
      if (seen.add(s) && !L10n.hasTranslation(s)) {
        print('$s\n');
      }
    }
  }
}
