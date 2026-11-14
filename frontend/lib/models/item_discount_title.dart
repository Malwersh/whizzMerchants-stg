String itemDiscountTitle(
    {required String customTitle,
    required bool percentage,
    required String value,
    required int itemCount}) {
  final custom = customTitle.trim();
  if (custom.isNotEmpty) return custom;
  final number = double.tryParse(value);
  final amount = number == null
      ? value.trim()
      : number == number.truncateToDouble()
          ? number.toInt().toString()
          : number.toString();
  return 'خصم $amount${percentage ? '٪' : ' د.ع'} على ${itemCount == 1 ? 'وجبة' : '$itemCount وجبات'}';
}
