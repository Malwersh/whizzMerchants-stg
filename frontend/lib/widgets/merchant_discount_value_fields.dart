import 'package:flutter/material.dart';
import '../models/discount.dart';

/// Keep this workflow Arabic until the language-switching work is completed.
Widget arabicMerchantDiscountContent(
        BuildContext context, WidgetBuilder builder) =>
    Localizations.override(
      context: context,
      locale: const Locale('ar'),
      child: Builder(
          builder: (context) => Directionality(
                textDirection: TextDirection.rtl,
                child: builder(context),
              )),
    );

/// Full-width fields keep both Arabic labels and menu items readable on phones.
class MerchantDiscountValueFields extends StatelessWidget {
  final DiscountType type;
  final TextEditingController controller;
  final ValueChanged<DiscountType> onTypeChanged;

  const MerchantDiscountValueFields({
    super.key,
    required this.type,
    required this.controller,
    required this.onTypeChanged,
  });

  static const labels = {
    DiscountType.percentage: 'نسبة مئوية',
    DiscountType.fixedAmount: 'مبلغ ثابت',
    DiscountType.conditional: 'خصم مشروط',
    DiscountType.buyXGetY: 'اشترِ كمية واحصل على أخرى',
    DiscountType.freeDelivery: 'توصيل مجاني',
  };

  @override
  Widget build(BuildContext context) {
    final parsed = double.tryParse(controller.text);
    final percentages = <double>{
      10,
      15,
      20,
      25,
      30,
      35,
      40,
      45,
      50,
      if (parsed != null && parsed > 0 && parsed <= 100) parsed,
    }.toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<DiscountType>(
          initialValue: type,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'نوع الخصم',
            border: OutlineInputBorder(),
          ),
          items: DiscountType.values
              .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(labels[value]!,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) onTypeChanged(value);
          },
        ),
        const SizedBox(height: 16),
        if (type == DiscountType.percentage)
          DropdownButtonFormField<double>(
            key: const ValueKey('discount-percentage'),
            initialValue: percentages.contains(parsed) ? parsed : 10,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'نسبة الخصم',
              border: OutlineInputBorder(),
            ),
            items: percentages
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text('${value % 1 == 0 ? value.toInt() : value}٪'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) controller.text = value.toString();
            },
          )
        else if (type == DiscountType.fixedAmount)
          TextFormField(
            key: const ValueKey('discount-fixed-amount'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'مبلغ الخصم بالدينار العراقي',
              hintText: 'مثال: 500',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final amount = double.tryParse(value ?? '');
              return amount == null || !amount.isFinite || amount <= 0
                  ? 'أدخل مبلغ خصم أكبر من صفر'
                  : null;
            },
          ),
      ],
    );
  }
}
