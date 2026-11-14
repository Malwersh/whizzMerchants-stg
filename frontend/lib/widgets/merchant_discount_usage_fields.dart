import 'package:flutter/material.dart';

class MerchantDiscountUsageFields extends StatelessWidget {
  final TextEditingController total, customer, cap;
  final bool percentage;
  const MerchantDiscountUsageFields({super.key, required this.total, required this.customer, required this.cap, required this.percentage});
  static String normalize(String text) => text.trim().replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
    final code = match[0]!.codeUnitAt(0);
    return (code - (code >= 0x06f0 ? 0x06f0 : 0x0660)).toString();
  });
  static int? parse(String text) => int.tryParse(normalize(text));
  static String? validate(String? text) {
    final value = normalize(text ?? '');
    if (value.isEmpty) return null;
    final number = int.tryParse(value);
    return !RegExp(r'^\d+$').hasMatch(value) || number == null || number < 1 || number > 1000000000
        ? 'أدخل عددًا صحيحًا أكبر من صفر، أو اترك الحقل فارغًا.' : null;
  }
  Widget field(TextEditingController controller, String label, String helper) => Padding(
    padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: controller,
      keyboardType: TextInputType.number, validator: validate,
      decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 4, border: const OutlineInputBorder())));
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('حدود استخدام الخصم', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    field(customer, 'عدد الاستخدامات لكل زبون', 'مثال: ١ يسمح لكل زبون باستخدام العرض مرة واحدة. فارغ = بلا حد لكل زبون.'),
    field(total, 'إجمالي استخدامات العرض لجميع الزبائن', 'مثال: ١٠٠ يعني تطبيق العرض على ١٠٠ طلب إجمالًا. فارغ = بلا حد. يلزم تحديده قبل اعتماد مشاركة تتحمل المنصة جزءًا منها.'),
    if (percentage) field(cap, 'أقصى قيمة خصم للطلب (د.ع)', 'لخصم النسبة المئوية: هذا السقف مطلوب عند مشاركة المنصة في التمويل.'),
    const Text('اضبط الحدود قبل اعتماد المشاركة؛ الشروط المعتمدة لا يمكن تعديلها.'),
  ]);
}
