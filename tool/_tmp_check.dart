import 'package:laundry/services/i18n/translations_en.dart';
void main(){
 for(final e in kEnglish.entries){
  final ar=RegExp(r'[\u0600-\u06FF]').hasMatch(e.key);
  if(!ar) print('NO_AR: ${e.key} => ${e.value}');
  if(e.key==e.value) print('SAME: ${e.key}');
 }
}
