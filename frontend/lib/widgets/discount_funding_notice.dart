import 'package:flutter/material.dart';

/// Discloses the source-funded default without inferring live branch consent.
class DiscountFundingNotice extends StatelessWidget {
  final bool editing;
  final bool delivery;
  final VoidCallback? onReview;
  const DiscountFundingNotice({super.key, this.editing = false,
    this.delivery = false, this.onReview});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final summary = delivery
        ? (ar ? 'التوصيل المجاني يتطلب سياسة تمويل توصيل معتمدة وميزانية متاحة. حفظ القسيمة لا ينشئ هذا التمويل.'
            : 'Free delivery requires an approved delivery funding policy and available budget. Saving a coupon does not create that funding.')
        : (ar ? 'يتحمل المتجر تكلفة خصم المنتجات افتراضياً. تُطبّق المشاركة فقط وفق اتفاقية معتمدة تطابق العرض والفرع عند تأكيد الطلب.'
            : 'The merchant pays for goods discounts by default. Sharing applies only under an approved agreement matching this offer and branch at checkout.');
    final change = editing && !delivery
        ? (ar ? 'تعديل محتوى العرض أو شروطه قد يُبطل مطابقة اتفاقية المشاركة الحالية. عند غياب مشاركة مطابقة يتحمل المتجر كامل الخصم. راجع الاتفاقيات وجدّد الموافقة على المشاركة بعد التعديل.'
            : 'Editing offer content or terms can invalidate the current sharing agreement. Without matching sharing, the merchant pays the full discount. Review agreements and renew sharing consent after editing.')
        : (ar ? 'حفظ الخصم أو تفعيله لا ينشئ اتفاقية مشاركة جديدة.'
            : 'Saving or activating a discount does not create a new sharing agreement.');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ar ? 'من يتحمل تكلفة الخصم؟' : 'Who pays for this discount?',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6), Text(summary),
        const SizedBox(height: 6), Text(change),
        if (onReview != null) TextButton(onPressed: onReview,
          child: Text(ar ? 'مراجعة الاتفاقيات التجارية' : 'Review commercial agreements')),
      ]),
    );
  }
}
