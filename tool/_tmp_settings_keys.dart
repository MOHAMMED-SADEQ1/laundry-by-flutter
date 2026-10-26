import 'package:laundry/services/settings/setting_option.dart';

void main() {
  for (final o in SettingOptions.all) {
    print('LABEL\u0001${o.key}\u0001${o.label}');
    print('DESC\u0001${o.key}\u0001${o.description}');
    o.choiceLabels?.forEach((k, v) => print('CHOICE\u0001${o.key}.$k\u0001$v'));
  }
}
