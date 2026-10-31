import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:laundry/controller/addeditcategorycontroller.dart';
import 'package:laundry/controller/invoicecontroller.dart';
import 'package:laundry/core/theme/app_colors.dart';
import 'package:laundry/services/i18n/currency.dart';
import 'package:laundry/services/i18n/l10n.dart';
import 'package:laundry/services/i18n/ui_direction.dart';
import 'package:laundry/services/invoice/invoice_lines.dart';

/// حوار تعديل بند في الفاتورة — **الكمية والسعر والخدمة والملاحظة**.
///
/// كان البند قبل هذا الحوار «إمّا كما أُضيف أو يُحذف ويُعاد إدخاله»: خطأ في
/// كمية أو سعر يعني حذفًا وإدخالًا من جديد أمام الزبون. الآن كل حقل قابل
/// للتصحيح، والإجمالي يُعاد حسابه لحظيًا قبل الحفظ.
///
/// 🚨 **الخدمة تُسعَّر من قائمة الأسعار الرسمية** عند تغييرها (لا يبقى سعر
/// الخدمة القديمة على الخدمة الجديدة) — ويُعلَن المصدر في الحوار. ولو لم
/// يكن الصنف في القائمة (أُعيدت تسميته/حُذف) يُترك السعر الحالي ويُنبَّه.
Future<void> showInvoiceLineEditDialog({
  required InvoiceController controller,
  required int index,
}) async {
  if (index < 0 || index >= controller.invoice.length) return;
  final original = Map<String, dynamic>.from(controller.invoice[index]);

  final updated = await Get.dialog<Map<String, dynamic>>(
    Directionality(
      textDirection: L10n.isRtl ? appTextDirection : TextDirection.ltr,
      child: _LineEditDialog(item: original),
    ),
    barrierColor: Colors.black54,
  );
  if (updated == null) return;

  final result = controller.updateItem(index, updated);

  if (result.outcome == LineAddOutcome.mergedByEdit) {
    Get.snackbar(
      tr('دُمج البندان'),
      trf('{0} — {1}: صار البند مطابقًا لبند موجود، فدُمجت الكميتان في سطر واحد ({2}).', [
        localizedText(result.name, result.nameEn),
        tr(result.service),
        '${result.quantity}',
      ]),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.info,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.merge_type, color: Colors.white),
    );
  }
}

class _LineEditDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  const _LineEditDialog({required this.item});

  @override
  State<_LineEditDialog> createState() => _LineEditDialogState();
}

class _LineEditDialogState extends State<_LineEditDialog> {
  late int _quantity;
  late String _service;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _noteCtrl;
  Map<String, dynamic>? _catalogRow;
  String _priceSource = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _quantity = InvoiceLines.quantityOf(widget.item);
    _service = '${widget.item['content'] ?? ServiceKind.normalWash}';
    _qtyCtrl = TextEditingController(text: '$_quantity');
    _priceCtrl = TextEditingController(
      text: InvoiceLines.priceOf(widget.item).toStringAsFixed(2),
    );
    _noteCtrl = TextEditingController(text: '${widget.item['note'] ?? ''}');
    _catalogRow = _findCatalogRow();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// صفّ الصنف في قائمة الأسعار — مصدر تسعير الخدمات.
  ///
  /// المطابقة بالتطبيع لا حرفيًّا: «ثوب أبيض » و«ثوب ابيض» صنف واحد.
  Map<String, dynamic>? _findCatalogRow() {
    if (!Get.isRegistered<AddCategoryController>()) return null;
    final target = InvoiceLines.normalize(widget.item['vestments']);
    if (target.isEmpty) return null;
    for (final row in Get.find<AddCategoryController>().clothing) {
      if (InvoiceLines.normalize(row['clothing_name']) == target) return row;
    }
    return null;
  }

  double get _price => InvoiceLines.money(_priceCtrl.text);

  double get _lineTotal => InvoiceLines.money(_price * _quantity);

  void _setQuantity(int value) {
    final safe = value.clamp(
      InvoiceLines.minQuantity,
      InvoiceLines.maxQuantity,
    );
    setState(() {
      _quantity = safe;
      _qtyCtrl.text = '$safe';
      _error = '';
    });
  }

  /// تغيير الخدمة: يجلب سعرها من القائمة الرسمية إن وُجد الصنف.
  void _setService(String label) {
    if (label == _service) return;
    final row = _catalogRow;
    setState(() {
      _service = label;
      _error = '';
      if (row == null) {
        _priceSource = tr('الصنف غير موجود في قائمة الأسعار — عدّل السعر يدويًّا');
        return;
      }
      final price = InvoiceLines.money(row[ServiceKind.priceColumn(label)]);
      _priceCtrl.text = price.toStringAsFixed(2);
      _priceSource = trf('سعر «{0}» من قائمة الأسعار: {1}', [
        tr(label),
        price.toStringAsFixed(2),
      ]);
    });
  }

  void _save() {
    final qty = int.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    if (qty == null ||
        qty < InvoiceLines.minQuantity ||
        qty > InvoiceLines.maxQuantity) {
      setState(() => _error = trf('الكمية يجب أن تكون بين {0} و{1}', [
        '${InvoiceLines.minQuantity}',
        '${InvoiceLines.maxQuantity}',
      ]));
      return;
    }
    final priceText = _priceCtrl.text.trim();
    final price = double.tryParse(priceText.replaceAll(',', '.'));
    if (price == null || price < 0) {
      setState(() => _error = tr('سعر غير صالح — اكتب رقمًا موجبًا'));
      return;
    }

    final updated = Map<String, dynamic>.from(widget.item);
    updated['count'] = qty;
    updated['price'] = InvoiceLines.money(price);
    updated['total_price'] = InvoiceLines.money(InvoiceLines.money(price) * qty);

    if (_service != '${widget.item['content'] ?? ''}') {
      updated['content'] = _service;
      // الترجمة المخزَّنة للخدمة القديمة صارت كاذبة ⇒ تُحذف لا تُترك.
      updated.remove('content_en');
    }

    final note = _noteCtrl.text.trim();
    if (note.isEmpty) {
      updated.remove('note');
      updated.remove('note_en');
    } else {
      if (note != '${widget.item['note'] ?? ''}'.trim()) updated.remove('note_en');
      updated['note'] = note;
    }

    Get.back(result: updated);
  }

  @override
  Widget build(BuildContext context) {
    final name = localizedText(
      '${widget.item['vestments'] ?? ''}',
      widget.item['vestments_en']?.toString(),
    );

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── رأس ───
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('تعديل البند'),
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('إغلاق'),
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── الخدمة ───
              _label(tr('الخدمة')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ServiceKind.all
                    .map(
                      (label) => _ServiceChip(
                        label: tr(label),
                        selected: label == _service,
                        onTap: () => _setService(label),
                      ),
                    )
                    .toList(),
              ),
              if (_priceSource.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 13,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _priceSource,
                          style: const TextStyle(
                            fontFamily: 'cairo',
                            fontSize: 10.5,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // ─── الكمية والسعر ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _quantityField()),
                  const SizedBox(width: 10),
                  Expanded(child: _priceField()),
                ],
              ),
              const SizedBox(height: 12),

              // ─── الملاحظة ───
              _label(tr('ملاحظة')),
              const SizedBox(height: 6),
              TextField(
                controller: _noteCtrl,
                maxLength: 60,
                style: const TextStyle(fontFamily: 'cairo', fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: tr('بقع، تلف، قصّات… (اتركه فارغًا للحذف)'),
                  prefixIcon: const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ─── الإجمالي الحيّ ───
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calculate_outlined,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr('إجمالي البند'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${_lineTotal.toStringAsFixed(2)} ${Currency.symbol}',
                      style: const TextStyle(
                        fontFamily: 'cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error,
                    style: const TextStyle(
                      fontFamily: 'cairo',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // ─── الأفعال ───
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        tr('إلغاء'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(
                        Icons.check,
                        size: 17,
                        color: Colors.white,
                      ),
                      label: Text(
                        tr('حفظ التعديل'),
                        style: const TextStyle(
                          fontFamily: 'cairo',
                          fontSize: 13,
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

  Widget _label(String text) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'cairo',
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _quantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(tr('الكمية')),
        const SizedBox(height: 6),
        Row(
          children: [
            _SquareButton(
              icon: Icons.remove,
              color: AppColors.danger,
              onTap: () => _setQuantity(_quantity - 1),
            ),
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null && parsed >= InvoiceLines.minQuantity) {
                    setState(() {
                      _quantity = parsed.clamp(
                        InvoiceLines.minQuantity,
                        InvoiceLines.maxQuantity,
                      );
                      _error = '';
                    });
                  }
                },
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                decoration: _fieldDecoration(),
              ),
            ),
            _SquareButton(
              icon: Icons.add,
              color: AppColors.success,
              onTap: () => _setQuantity(_quantity + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _priceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(tr('سعر الوحدة')),
        const SizedBox(height: 6),
        TextField(
          controller: _priceCtrl,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() => _error = ''),
          style: const TextStyle(
            fontFamily: 'cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          decoration: _fieldDecoration(
            suffix: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                Currency.symbol,
                style: const TextStyle(
                  fontFamily: 'cairo',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({Widget? suffix}) => InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 0),
    filled: true,
    fillColor: AppColors.surfaceSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SquareButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ServiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
