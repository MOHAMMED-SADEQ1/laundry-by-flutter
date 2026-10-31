import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:laundry/services/i18n/doc_language.dart';
import 'package:laundry/services/i18n/translations_en.dart';
import 'package:laundry/services/pdf/doc_template.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/services/settings/app_settings_service.dart';
import 'package:laundry/services/settings/setting_option.dart';
import 'package:laundry/sqldb.dart';

/// **مخزن قوالب المستندات** — الطبقة الوحيدة التي تقرأ/تكتب
/// `doc_template_invoice` و`doc_template_statement` في جدول `settings`.
///
/// ## لماذا خدمة وكاش؟
/// المولّدات الأربعة (`generatePdfData` · `generateCustomerStatementPdf` ·
/// ملخّص الوردية · `LaundrySlipPdf`) تبني خرائط بياناتها في مسارات **متزامنة**
/// أحيانًا ثم تُمرَّر إلى `compute` الذي يعمل في عزل مستقلّ لا يرى القاعدة ولا
/// `SharedPreferences`. فالحلّ: نقرأ مرة واحدة عند الإقلاع إلى كاش في
/// الذاكرة، ثم نُصدّر خريطة أنواع أوّلية فقط عبر [transport].
///
/// ## العلاقة بالخيارات القديمة
/// مجموعة `invoiceDisplay` فيها 15 خيارًا يتحكّم ببعض ما يظهر. القالب
/// **مرآتها** الآن:
///   - لا قالب محفوظ ⇒ يُزرع من قيمها الحالية ([DocTemplate.seededFromLegacy])
///     فلا يتغيّر شكل أي فاتورة قائمة بعد التحديث.
///   - قالب محفوظ ⇒ هو المرجع. وأي تعديل لاحق على خيار قديم يُزامَن إليه
///     عبر [mirrorLegacy] كي لا تتناقض الشاشتان.
class DocTemplateService {
  DocTemplateService._();
  static final DocTemplateService instance = DocTemplateService._();

  final SqlDB _db = SqlDB();

  /// كاش في الذاكرة — يُملأ بـ[loadAll] عند الإقلاع.
  final Map<DocKind, DocTemplate> _cache = <DocKind, DocTemplate>{};

  /// هل تمّ التحميل من القاعدة؟ (للحراس والتشخيص)
  bool get isLoaded => _cache.length == DocKind.values.length;

  /// القالب من الكاش — **متزامن**، ويعود للافتراضي إن لم يُحمَّل بعد.
  DocTemplate template(DocKind kind) =>
      _cache[kind] ?? DocTemplate.defaults(kind);

  /// خريطة النقل إلى `compute` — أنواع أوّلية فقط.
  ///
  /// **اللغة تُختم هنا من إعداد «لغة الفاتورة والمستندات»**، لا من لغة
  /// الواجهة. سببان:
  ///   1. العزل لا يرى `L10n` أصلًا، فأي قراءة لها هناك تعطي الافتراضي.
  ///   2. لغة الورقة قرار مالي مستقلّ: تبديل لغة الشاشة لا يجوز أن يغيّر
  ///      لغة الفاتورة الضريبية.
  ///
  /// [language] للاختبارات فقط؛ غيابه ⇒ الإعداد المحفوظ، ثم العربية.
  Map<String, dynamic> transport(DocKind kind, {DocLanguage? language}) {
    final data = template(kind).toTransport();
    final settings = AppSettingsService.instance;
    final lang =
        language ??
        (settings.isLoaded ? settings.docLanguage : DocLanguage.defaultLanguage);
    data['docLang'] = lang.code;
    if (lang.isEnglish) data['docEnglish'] = kEnglish;
    return data;
  }

  /// يحمّل القوالب من القاعدة. يُستدعى في `main` بعد إعدادات النظام.
  ///
  /// لا يرمي أبدًا: أي فشل (قاعدة غير جاهزة · JSON تالف) يُبقي الافتراضي،
  /// لأن فشل تحميل قالب **لا يجوز** أن يمنع الطباعة.
  Future<void> loadAll() async {
    for (final kind in DocKind.values) {
      await load(kind, force: true);
    }
  }

  /// يقرأ قالبًا واحدًا. عند غياب صفّ محفوظ يُزرع من الخيارات القديمة.
  Future<DocTemplate> load(DocKind kind, {bool force = false}) async {
    if (!force && _cache.containsKey(kind)) return _cache[kind]!;
    try {
      final rows = await _db.safeRead(
        'settings',
        where: 'key = ?',
        whereArgs: <Object?>[DocCatalog.storageKey(kind)],
        limit: 1,
      );
      final raw = rows.isEmpty ? '' : (rows.first['value']?.toString() ?? '');
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        final t = DocTemplate.fromJson(
          kind,
          decoded is Map ? decoded : null,
        );
        _cache[kind] = t;
        return t;
      }
      // لا قالب محفوظ: نبدأ من الشكل الحالي للمستخدم لا من الصفر.
      final t = DocTemplate.defaults(
        kind,
      ).seededFromLegacy(_legacyValues(kind));
      _cache[kind] = t;
      return t;
    } catch (e) {
      debugPrint('DocTemplateService.load(${kind.name}) error: $e');
      final t = DocTemplate.defaults(kind);
      _cache[kind] = t;
      return t;
    }
  }

  /// يحفظ القالب (upsert في `settings`) ويُحدّث الكاش.
  ///
  /// الكتابة عبر `updateSetting` لأنها `ConflictAlgorithm.replace` وتتجاوز
  /// قيد `key` الفريد — ثم نُسجّل تدقيقًا لأن التصميم قرار تجاري مرئي للزبون.
  Future<void> save(DocKind kind, DocTemplate t) async {
    final key = DocCatalog.storageKey(kind);
    await _db.updateSetting(key, jsonEncode(t.toJson()));
    _cache[kind] = t;
    try {
      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: 'doc_template_update',
        tableName: 'settings',
        newValues: jsonEncode(<String, Object?>{
          'key': key,
          'fields': t.enabled.length,
          'modified': t.isModified,
        }),
      );
    } catch (e) {
      debugPrint('doc template audit skipped: $e');
    }
  }

  /// يعيد القالب للافتراضي (ويحفظ ذلك صراحةً، فلا يُعاد الزرع القديم).
  Future<DocTemplate> reset(DocKind kind) async {
    final t = DocTemplate.defaults(kind);
    await save(kind, t);
    return t;
  }

  /// يزامن خيارًا قديمًا واحدًا إلى القالب (يُستدعى من `updateSetting`).
  ///
  /// **لا يرمي ولا يحفظ إن لم يكن للخيار مرادف** — فالمزامنة تحسين لا شرط.
  /// يعيد `true` إن تغيّر شيء فعلًا.
  Future<bool> mirrorLegacy(String settingKey, String value) async {
    for (final kind in DocKind.values) {
      final field = DocCatalog.fieldByLegacy(kind, settingKey);
      if (field == null) continue;
      final current = template(kind);
      final v = value.trim();
      final next =
          field.legacyToggle != null
              ? current.withField(
                field.key,
                enabled: v == '1' || v.toLowerCase() == 'true',
              )
              : current.withField(field.key, text: v);
      if (next.toJson().toString() == current.toJson().toString()) return false;
      await save(kind, next);
      return true;
    }
    return false;
  }

  /// القيم الحالية للخيارات القديمة المرتبطة بهذا النوع.
  Map<String, String> _legacyValues(DocKind kind) {
    final out = <String, String>{};
    final settings = AppSettingsService.instance;
    if (!settings.isLoaded) return out;
    for (final f in DocCatalog.legacyFields(kind)) {
      final key = f.legacyToggle ?? f.legacyText;
      if (key == null) continue;
      final option = SettingOptions.byKey(key);
      if (option == null) continue;
      out[key] = settings.rawOf(option);
    }
    return out;
  }
}
