import 'package:get/get.dart';
import 'package:laundry/config/constants.dart';
import 'package:laundry/core/constant/routes.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/translations_en.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/security_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/view/widget/license/license_expiry_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends GetxController {
  var username = ''.obs;
  var password = ''.obs;
  var isLoading = false.obs;
  var showPassword = false.obs;

  void login() async {
    if (username.value.isEmpty || password.value.isEmpty) {
      Get.snackbar(
        tr('خطأ'),
        tr('أدخل اسم المستخدم وكلمة المرور'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    await Future.delayed(Duration(seconds: 1));

    SqlDB db = SqlDB();

    // Search for user with parameterized query
    final users = await db.safeRead(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.value],
    );

    if (users.isEmpty) {
      Get.snackbar(
        tr('خطأ'),
        tr('اسم المستخدم غير موجود'),
        snackPosition: SnackPosition.BOTTOM,
      );
      isLoading.value = false;
      return;
    }

    final user = users.first;
    final storedHash = user['password_hash'] as String;

    // Verify password
    if (!SecurityService.verifyPassword(password.value, storedHash)) {
      Get.snackbar(
        tr('خطأ'),
        tr('كلمة المرور غير صحيحة'),
        snackPosition: SnackPosition.BOTTOM,
      );
      isLoading.value = false;
      return;
    }

    // Login successful
    final userId = user['user_id'] as int;
    final role = user['role'] as String;

    await SessionManager.login(userId, username.value, role);

    // 🛡️ تحميل صلاحيات الداخل **قبل** الانتقال — فلا تظهر أي شاشة أو زر
    // محمي لحظةً ثم يختفي. التحميل يقرأ إسنادات دوره وتجاوزاته الفردية.
    await PermissionService.load();

    // Initialize invoice counter if first time
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(AppConstants.spCounterInvoice) == null) {
      await prefs.setInt(
        AppConstants.spCounterInvoice,
        AppConstants.invoiceCounterStart,
      );
    }

    // Insert default clothing items if table is empty
    final clothingCount = await db.safeRead('clothing');
    if (clothingCount.isEmpty) {
      await _insertDefaultClothing(db);
    }

    // Insert default categories
    final categoryCount = await db.safeRead('categories');
    if (categoryCount.isEmpty) {
      await _insertDefaultCategories(db);
    }

    Get.offNamed(AppRoute.homepage);
    isLoading.value = false;

    // تنبيه «قرب انتهاء الاشتراك» مع زر تجديد مباشر — مرة واحدة في اليوم
    // (انظر `showLicenseExpiryNoticeIfDue`). يُعرض بعد الدخول لا قبله، فلا
    // يُقاطَع المستخدم أثناء إدخال بياناته.
    showLicenseExpiryNoticeIfDue();
  }

  Future<void> _insertDefaultClothing(SqlDB db) async {
    final items = <Map<String, dynamic>>[
      {
        'clothing_name': 'ثوب أبيض',
        'normal_washing_and_ironing_price': 5.0,
        'urgent_washing_and_ironing_price': 7.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 1,
      },
      {
        'clothing_name': 'ثوب ملون',
        'normal_washing_and_ironing_price': 6.0,
        'urgent_washing_and_ironing_price': 8.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 1,
      },
      {
        'clothing_name': 'ثوب صوف',
        'normal_washing_and_ironing_price': 7.0,
        'urgent_washing_and_ironing_price': 10.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 1,
      },
      {
        'clothing_name': 'غترة',
        'normal_washing_and_ironing_price': 4.0,
        'urgent_washing_and_ironing_price': 6.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 2,
      },
      {
        'clothing_name': 'شماغ',
        'normal_washing_and_ironing_price': 4.0,
        'urgent_washing_and_ironing_price': 6.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 2,
      },
      {
        'clothing_name': 'طاقية',
        'normal_washing_and_ironing_price': 1.0,
        'urgent_washing_and_ironing_price': 2.0,
        'normal_ironing_price': 1.0,
        'urgent_ironing_price': 1.0,
        'category_id': 3,
      },
      {
        'clothing_name': 'فانيلة داخلية',
        'normal_washing_and_ironing_price': 3.0,
        'urgent_washing_and_ironing_price': 5.0,
        'normal_ironing_price': 1.0,
        'urgent_ironing_price': 2.0,
        'category_id': 3,
      },
      {
        'clothing_name': 'سروال قصير',
        'normal_washing_and_ironing_price': 3.0,
        'urgent_washing_and_ironing_price': 5.0,
        'normal_ironing_price': 1.0,
        'urgent_ironing_price': 2.0,
        'category_id': 3,
      },
      {
        'clothing_name': 'سروال طويل',
        'normal_washing_and_ironing_price': 3.0,
        'urgent_washing_and_ironing_price': 5.0,
        'normal_ironing_price': 1.0,
        'urgent_ironing_price': 2.0,
        'category_id': 3,
      },
      {
        'clothing_name': 'جوارب',
        'normal_washing_and_ironing_price': 1.0,
        'urgent_washing_and_ironing_price': 2.0,
        'normal_ironing_price': 1.0,
        'urgent_ironing_price': 1.0,
        'category_id': 3,
      },
      {
        'clothing_name': 'بدلة عسكرية',
        'normal_washing_and_ironing_price': 8.0,
        'urgent_washing_and_ironing_price': 10.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 4.0,
        'category_id': 4,
      },
      {
        'clothing_name': 'بدلة افرنجي',
        'normal_washing_and_ironing_price': 15.0,
        'urgent_washing_and_ironing_price': 17.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 5.0,
        'category_id': 4,
      },
      {
        'clothing_name': 'بدلة صوف',
        'normal_washing_and_ironing_price': 20.0,
        'urgent_washing_and_ironing_price': 25.0,
        'normal_ironing_price': 5.0,
        'urgent_ironing_price': 7.0,
        'category_id': 4,
      },
      {
        'clothing_name': 'بدلة سفاري',
        'normal_washing_and_ironing_price': 20.0,
        'urgent_washing_and_ironing_price': 25.0,
        'normal_ironing_price': 5.0,
        'urgent_ironing_price': 7.0,
        'category_id': 4,
      },
      {
        'clothing_name': 'بدلة رياضية',
        'normal_washing_and_ironing_price': 9.0,
        'urgent_washing_and_ironing_price': 11.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 4,
      },
      {
        'clothing_name': 'بدلة باكستاني',
        'normal_washing_and_ironing_price': 10.0,
        'urgent_washing_and_ironing_price': 12.0,
        'normal_ironing_price': 4.0,
        'urgent_ironing_price': 5.0,
        'category_id': 4,
      },
      {
        'clothing_name': 'جاكيت',
        'normal_washing_and_ironing_price': 10.0,
        'urgent_washing_and_ironing_price': 12.0,
        'normal_ironing_price': 4.0,
        'urgent_ironing_price': 5.0,
        'category_id': 5,
      },
      {
        'clothing_name': 'بنطلون',
        'normal_washing_and_ironing_price': 5.0,
        'urgent_washing_and_ironing_price': 6.0,
        'normal_ironing_price': 2.0,
        'urgent_ironing_price': 3.0,
        'category_id': 5,
      },
      {
        'clothing_name': 'بنطلون صوف',
        'normal_washing_and_ironing_price': 6.0,
        'urgent_washing_and_ironing_price': 8.0,
        'normal_ironing_price': 2.0,
        'urgent_ironing_price': 3.0,
        'category_id': 5,
      },
      {
        'clothing_name': 'قايش/قبعة',
        'normal_washing_and_ironing_price': 0.0,
        'urgent_washing_and_ironing_price': 0.0,
        'normal_ironing_price': 0.0,
        'urgent_ironing_price': 0.0,
        'category_id': 6,
      },
      {
        'clothing_name': 'طماق',
        'normal_washing_and_ironing_price': 0.0,
        'urgent_washing_and_ironing_price': 0.0,
        'normal_ironing_price': 0.0,
        'urgent_ironing_price': 0.0,
        'category_id': 6,
      },
      {
        'clothing_name': 'معطف/بالطو',
        'normal_washing_and_ironing_price': 5.0,
        'urgent_washing_and_ironing_price': 7.0,
        'normal_ironing_price': 2.0,
        'urgent_ironing_price': 3.0,
        'category_id': 5,
      },
      {
        'clothing_name': 'قميص',
        'normal_washing_and_ironing_price': 5.0,
        'urgent_washing_and_ironing_price': 7.0,
        'normal_ironing_price': 2.0,
        'urgent_ironing_price': 3.0,
        'category_id': 5,
      },
      {
        'clothing_name': 'بلوزة حرير',
        'normal_washing_and_ironing_price': 10.0,
        'urgent_washing_and_ironing_price': 12.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 5.0,
        'category_id': 7,
      },
      {
        'clothing_name': 'فستان',
        'normal_washing_and_ironing_price': 25.0,
        'urgent_washing_and_ironing_price': 30.0,
        'normal_ironing_price': 8.0,
        'urgent_ironing_price': 10.0,
        'category_id': 7,
      },
      {
        'clothing_name': 'فستان حرير',
        'normal_washing_and_ironing_price': 40.0,
        'urgent_washing_and_ironing_price': 45.0,
        'normal_ironing_price': 10.0,
        'urgent_ironing_price': 12.0,
        'category_id': 7,
      },
      {
        'clothing_name': 'فستان قطعتين',
        'normal_washing_and_ironing_price': 30.0,
        'urgent_washing_and_ironing_price': 35.0,
        'normal_ironing_price': 10.0,
        'urgent_ironing_price': 12.0,
        'category_id': 7,
      },
      {
        'clothing_name': 'تنورة',
        'normal_washing_and_ironing_price': 15.0,
        'urgent_washing_and_ironing_price': 20.0,
        'normal_ironing_price': 5.0,
        'urgent_ironing_price': 8.0,
        'category_id': 7,
      },
      {
        'clothing_name': 'بشت/فروة',
        'normal_washing_and_ironing_price': 4.0,
        'urgent_washing_and_ironing_price': 6.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'قميص حرير',
        'normal_washing_and_ironing_price': 25.0,
        'urgent_washing_and_ironing_price': 30.0,
        'normal_ironing_price': 5.0,
        'urgent_ironing_price': 8.0,
        'category_id': 5,
      },
      {
        'clothing_name': 'عباية',
        'normal_washing_and_ironing_price': 25.0,
        'urgent_washing_and_ironing_price': 30.0,
        'normal_ironing_price': 5.0,
        'urgent_ironing_price': 8.0,
        'category_id': 7,
      },
      {
        'clothing_name': 'قميص نوم',
        'normal_washing_and_ironing_price': 5.0,
        'urgent_washing_and_ironing_price': 7.0,
        'normal_ironing_price': 2.0,
        'urgent_ironing_price': 3.0,
        'category_id': 7,
      },
      {
        'clothing_name': 'شرشف مزدوج',
        'normal_washing_and_ironing_price': 7.0,
        'urgent_washing_and_ironing_price': 10.0,
        'normal_ironing_price': 2.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'كيس مخدة',
        'normal_washing_and_ironing_price': 3.0,
        'urgent_washing_and_ironing_price': 5.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'شرشف مفرد',
        'normal_washing_and_ironing_price': 7.0,
        'urgent_washing_and_ironing_price': 10.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'روب حمام',
        'normal_washing_and_ironing_price': 15.0,
        'urgent_washing_and_ironing_price': 20.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 4.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'بيجامة',
        'normal_washing_and_ironing_price': 8.0,
        'urgent_washing_and_ironing_price': 10.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 5.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'فانيلة صوف',
        'normal_washing_and_ironing_price': 5.0,
        'urgent_washing_and_ironing_price': 6.0,
        'normal_ironing_price': 2.0,
        'urgent_ironing_price': 3.0,
        'category_id': 3,
      },
      {
        'clothing_name': 'منشفة/منديل',
        'normal_washing_and_ironing_price': 10.0,
        'urgent_washing_and_ironing_price': 13.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'بطانية',
        'normal_washing_and_ironing_price': 25.0,
        'urgent_washing_and_ironing_price': 30.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'مفرش',
        'normal_washing_and_ironing_price': 25.0,
        'urgent_washing_and_ironing_price': 30.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'ستائر',
        'normal_washing_and_ironing_price': 25.0,
        'urgent_washing_and_ironing_price': 30.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
      {
        'clothing_name': 'سجاد',
        'normal_washing_and_ironing_price': 15.0,
        'urgent_washing_and_ironing_price': 20.0,
        'normal_ironing_price': 3.0,
        'urgent_ironing_price': 3.0,
        'category_id': 8,
      },
    ];

    // 🚨 مصدر الترجمة **واحد**: القاموس في `translations_en.dart`.
    // كانت هنا خريطة `namesEn` مكرّرة (43 صنفًا) — تكرار يعني أن تصحيح
    // ترجمة في مكان لا يصل إلى الآخر، وأن الصنف القديم (`_en = NULL`)
    // يبقى عربيًّا لأن الواجهة لا تجد له مدخلًا في القاموس.
    for (final item in items) {
      final arabic = '${item['clothing_name']}';
      item['clothing_name_en'] = kEnglish[arabic] ?? '';
      await db.safeInsert('clothing', item);
    }
  }

  Future<void> _insertDefaultCategories(SqlDB db) async {
    final categories = <Map<String, dynamic>>[
      {
        'name': 'ملابس رجالية',
        'name_en': 'Men\'s clothing',
        'description': 'ثوب، شماغ، غترة',
        'description_en': 'Thobe, shemagh, ghutra',
      },
      {
        'name': 'إكسسوارات رجالية',
        'name_en': 'Men\'s accessories',
        'description': 'شماغ، غترة، طاقية',
        'description_en': 'Shemagh, ghutra, kufi cap',
      },
      {
        'name': 'ملابس داخلية',
        'name_en': 'Underwear',
        'description': 'فانيلة، سروال، جوارب',
        'description_en': 'Undershirt, trousers, socks',
      },
      {
        'name': 'بِدَل',
        'name_en': 'Suits',
        'description': 'عسكرية، افرنجية، صوف',
        'description_en': 'Military, Western, wool',
      },
      {
        'name': 'قمصان وبنطلونات',
        'name_en': 'Shirts and pants',
        'description': 'قميص، بنطلون، جاكيت',
        'description_en': 'Shirt, pants, jacket',
      },
      {
        'name': 'أكسسوارات',
        'name_en': 'Accessories',
        'description': 'قبعة، طماق',
        'description_en': 'Hat, leggings',
      },
      {
        'name': 'ملابس نسائية',
        'name_en': 'Women\'s clothing',
        'description': 'فستان، بلوزة، عباية',
        'description_en': 'Dress, blouse, abaya',
      },
      {
        'name': 'مفروشات',
        'name_en': 'Furnishings',
        'description': 'شرشف، مفرش، بطانية، ستائر',
        'description_en': 'Bedsheet, bedspread, blanket, curtains',
      },
    ];

    for (final cat in categories) {
      await db.safeInsert('categories', cat);
    }
  }

  void logout() async {
    await SessionManager.logout();
    // 🛡️ إفراغ كاش الصلاحيات عند الخروج — وإلا بقي المستخدم التالي يرى
    // صلاحيات سابقه حتى الدخول (وهو أسوأ تسريب ممكن في جهاز مشترك).
    PermissionService.clear();
    Get.offNamed(AppRoute.login);
  }

  void togglePasswordVisibility() {
    showPassword.value = !showPassword.value;
  }
}
