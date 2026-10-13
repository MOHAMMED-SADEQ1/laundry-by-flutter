import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/discount/discount_rules.dart';
import 'package:laundry/services/discount/discount_service.dart';
import 'package:laundry/services/permission/permission_service.dart';
import 'package:laundry/services/security/session_manager.dart';
import 'package:laundry/sqldb.dart';
import 'package:laundry/view/widget/common/animation_wrappers.dart';
import 'package:laundry/view/widget/common/common_widgets.dart';
import 'package:laundry/view/widget/customappbar.dart';

/// إدارة أكواد الخصم.
///
/// **لماذا شاشة كاملة؟** جدول `discounts` كان موجودًا في المخطط منذ أول
/// إصدار و**صفر كود** يقرأ منه أو يكتب فيه: ميزة معلنة وغير موجودة. الشاشة
/// هي الجزء الذي يجعل الأكواد قابلة للإنشاء والضبط والتعطيل بلا SQL.
class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  final DiscountService _service = DiscountService.instance;
  final SqlDB _db = SqlDB();

  List<Map<String, dynamic>> _codes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.all();
    if (!mounted) return;
    setState(() {
      _codes = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(
        title: 'أكواد الخصم',
        subtitle: '${_codes.length} كود',
        actions: IconButton(
          tooltip: 'كود جديد',
          onPressed: PermissionService.canManageDiscounts
              ? () => _openEditor()
              : null,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _codes.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _hintCard(),
                const SizedBox(height: 12),
                for (var i = 0; i < _codes.length; i++)
                  FadeInUp(
                    delayMs: (i * 40).clamp(0, 400),
                    child: _codeCard(_codes[i]),
                  ),
                const SizedBox(height: 20),
              ],
            ),
      floatingActionButton: PermissionService.canManageDiscounts
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: AppColors.success,
              icon: const Icon(Icons.local_offer, color: Colors.white),
              label: const Text(
                'كود خصم جديد',
                style: TextStyle(
                  fontFamily: 'cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            const Text(
              'لا توجد أكواد خصم',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أنشئ كودًا (نسبة أو مبلغًا) بصلاحية استخدام وتاريخ انتهاء، '
              'ثم أدخله في حوار الدفع ليُخصم من الفاتورة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 12,
                height: 1.7,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            if (PermissionService.canManageDiscounts)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'إنشاء كود',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hintCard() {
    return SoftCard(
      color: AppColors.info.withValues(alpha: 0.06),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'الخصم يُطبَّق قبل الضريبة: تُحتسب ضريبة القيمة المضافة على '
              'الصافي بعد الخصم، فلا يدفع الزبون ضريبة مبلغ لم يشتره. '
              'والكود لا يُخصم أكثر من قيمة الفاتورة مهما كان مبلغه.',
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                height: 1.7,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// حالة الكود محسوبة بالمنطق الخالص — لا تُكرَّر هنا.
  Widget _codeCard(Map<String, dynamic> code) {
    final check = DiscountRules.evaluate(
      record: code,
      gross: 100,
      today: DateTime.now(),
    );
    final active = ((code['is_active'] as num?)?.toInt() ?? 0) == 1;
    final isPercent =
        '${code['type'] ?? ''}'.toLowerCase() == 'percentage';
    final value = ((code['value'] ?? 0) as num).toDouble();
    final used = (code['current_uses'] as num?)?.toInt() ?? 0;
    final maxUses = (code['max_uses'] as num?)?.toInt();
    final color = check.valid
        ? AppColors.success
        : (active ? AppColors.warning : AppColors.danger);

    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${code['code'] ?? ''}',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${code['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                isPercent
                    ? '${_plain(value)}%'
                    : '${value.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(
                Icons.event_outlined,
                'من ${_short(code['start_date'])}'
                '${_shortOrNull(code['end_date']) == null ? ' — بلا انتهاء' : ' إلى ${_shortOrNull(code['end_date'])}'}',
                AppColors.textSecondary,
              ),
              _chip(
                Icons.repeat,
                maxUses == null || maxUses <= 0
                    ? 'استُخدم $used — بلا حدّ'
                    : 'استُخدم $used / $maxUses',
                (maxUses != null && maxUses > 0 && used >= maxUses)
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
              _chip(
                active ? Icons.check_circle_outline : Icons.block,
                active ? 'مُفعَّل' : 'معطَّل',
                active ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
          if (!check.valid && check.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                check.message,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  color: AppColors.warning,
                ),
              ),
            ),
          if (PermissionService.canManageDiscounts) ...[
            const Divider(height: 18),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _openEditor(code: code),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text(
                    'تعديل',
                    style: TextStyle(fontFamily: 'cairo', fontSize: 12.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _toggleActive(code, active),
                  icon: Icon(
                    active ? Icons.visibility_off_outlined : Icons.restore,
                    size: 17,
                    color: active ? AppColors.danger : AppColors.success,
                  ),
                  label: Text(
                    active ? 'تعطيل' : 'تفعيل',
                    style: TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 12.5,
                      color: active ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'cairo',
              fontSize: 10.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> code, bool active) async {
    if (active) {
      await _service.deactivate((code['discount_id'] as num).toInt());
    } else {
      await _service.save(
        id: (code['discount_id'] as num).toInt(),
        name: '${code['name'] ?? ''}',
        code: '${code['code'] ?? ''}',
        type: '${code['type'] ?? 'percentage'}',
        value: ((code['value'] ?? 0) as num).toDouble(),
        startDate: '${code['start_date'] ?? ''}',
        endDate: code['end_date']?.toString(),
        isActive: true,
        maxUses: (code['max_uses'] as num?)?.toInt(),
      );
    }
    await _db.logAudit(
      userId: SessionManager.currentUserId,
      action: active ? 'discount_deactivate' : 'discount_activate',
      tableName: 'discounts',
      recordId: (code['discount_id'] as num).toInt(),
      newValues: '{"code":"${code['code']}"}',
    );
    await _load();
  }

  Future<void> _openEditor({Map<String, dynamic>? code}) async {
    final result = await Get.dialog<Map<String, dynamic>>(
      _DiscountEditorDialog(existing: code),
      barrierDismissible: false,
      barrierColor: Colors.black54,
    );
    if (result == null) return;
    try {
      final id = await _service.save(
        id: (code?['discount_id'] as num?)?.toInt(),
        name: result['name'] as String,
        code: result['code'] as String,
        type: result['type'] as String,
        value: result['value'] as double,
        startDate: result['startDate'] as String,
        endDate: result['endDate'] as String?,
        isActive: result['isActive'] as bool,
        maxUses: result['maxUses'] as int?,
      );
      await _db.logAudit(
        userId: SessionManager.currentUserId,
        action: code == null ? 'discount_create' : 'discount_update',
        tableName: 'discounts',
        recordId: id,
        newValues:
            '{"code":"${result['code']}","type":"${result['type']}",'
            '"value":${result['value']}}',
      );
      await _load();
      Get.snackbar(
        'تم',
        code == null ? 'أُنشئ كود الخصم' : 'حُدِّث كود الخصم',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'تعذّر الحفظ',
        '$e'.replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  static String _plain(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static String _short(dynamic raw) => _shortOrNull(raw) ?? '—';

  static String? _shortOrNull(dynamic raw) {
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(text));
    } catch (_) {
      return text.length >= 10 ? text.substring(0, 10) : text;
    }
  }
}

/// حوار إنشاء/تعديل كود خصم.
class _DiscountEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _DiscountEditorDialog({this.existing});

  @override
  State<_DiscountEditorDialog> createState() => _DiscountEditorDialogState();
}

class _DiscountEditorDialogState extends State<_DiscountEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _maxUsesCtrl;

  String _type = 'percentage';
  bool _isActive = true;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: '${e?['name'] ?? ''}');
    _codeCtrl = TextEditingController(text: '${e?['code'] ?? ''}');
    _type = '${e?['type'] ?? 'percentage'}';
    _valueCtrl = TextEditingController(
      text: e == null ? '' : _plain(((e['value'] ?? 0) as num).toDouble()),
    );
    final maxUses = (e?['max_uses'] as num?)?.toInt();
    _maxUsesCtrl = TextEditingController(
      text: maxUses == null || maxUses <= 0 ? '' : '$maxUses',
    );
    _isActive = ((e?['is_active'] as num?)?.toInt() ?? 1) == 1;
    _startDate = _parse(e?['start_date']) ?? DateTime.now();
    _endDate = _parse(e?['end_date']);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _maxUsesCtrl.dispose();
    super.dispose();
  }

  static DateTime? _parse(dynamic raw) {
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty) return null;
    try {
      return DateTime.parse(text);
    } catch (_) {
      return null;
    }
  }

  static String _plain(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.')) ?? 0;
    final maxUsesRaw = _maxUsesCtrl.text.trim();
    final maxUses = maxUsesRaw.isEmpty ? null : int.tryParse(maxUsesRaw);

    if (name.isEmpty) {
      setState(() => _error = 'أدخل اسمًا للخصم');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'أدخل كودًا — هو ما يُكتب في الكاشير');
      return;
    }
    if (value <= 0) {
      setState(() => _error = 'أدخل قيمة أكبر من صفر');
      return;
    }
    if (_type == 'percentage' && value > 100) {
      setState(() => _error = 'النسبة لا تتجاوز 100%');
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      setState(() => _error = 'تاريخ الانتهاء قبل تاريخ البداية');
      return;
    }
    if (maxUsesRaw.isNotEmpty && (maxUses == null || maxUses <= 0)) {
      setState(() => _error = 'حدّ الاستخدام يجب أن يكون رقمًا أكبر من صفر');
      return;
    }

    Get.back(
      result: {
        'name': name,
        'code': code,
        'type': _type,
        'value': value,
        'startDate': _fmt(_startDate),
        'endDate': _endDate == null ? null : _fmt(_endDate!),
        'isActive': _isActive,
        'maxUses': maxUses,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPercent = _type == 'percentage';
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer,
                      color: AppColors.success, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.existing == null ? 'كود خصم جديد' : 'تعديل كود الخصم',
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'الاسم (وصف داخلي)',
                  hintText: 'مثال: خصم افتتاح الفرع',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'الكود',
                  hintText: 'مثال: WASH10',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _typeChip(
                      label: 'نسبة %',
                      selected: isPercent,
                      onTap: () => setState(() => _type = 'percentage'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _typeChip(
                      label: 'مبلغ ثابت',
                      selected: !isPercent,
                      onTap: () => setState(() => _type = 'fixed'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _valueCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isPercent ? 'النسبة (%)' : 'المبلغ (ر.س)',
                  hintText: isPercent ? '10 = خصم 10%' : '10 = خصم 10 ر.س',
                  prefixIcon: Icon(
                    isPercent ? Icons.percent : Icons.attach_money,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _maxUsesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'حدّ الاستخدام (اختياري)',
                  hintText: 'اتركه فارغًا لاستخدام بلا حدّ',
                  prefixIcon: Icon(Icons.repeat),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      label: 'يبدأ',
                      value: _fmt(_startDate),
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateField(
                      label: 'ينتهي',
                      value: _endDate == null ? 'بلا انتهاء' : _fmt(_endDate!),
                      onTap: () => _pickDate(isStart: false),
                      onClear: _endDate == null
                          ? null
                          : () => setState(() => _endDate = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text(
                  'مُفعَّل',
                  style: TextStyle(
                    fontFamily: 'cairo',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'المعطَّل يبقى محفوظًا لكنه لا يُطبَّق على أي فاتورة',
                  style: TextStyle(fontFamily: 'cairo', fontSize: 11),
                ),
                activeThumbColor: AppColors.success,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontFamily: 'cairo', fontSize: 13.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: _submit,
                      child: const Text(
                        'حفظ',
                        style: TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.success : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'cairo',
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today_outlined, size: 16)
              : IconButton(
                  tooltip: 'إزالة',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 16),
                ),
        ),
        child: Text(
          value,
          style: const TextStyle(fontFamily: 'cairo', fontSize: 12.5),
        ),
      ),
    );
  }
}
