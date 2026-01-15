import 'package:flutter/material.dart';
import '../core/design_system/design_system.dart';

class CancelReasonBottomSheet extends StatefulWidget {
  const CancelReasonBottomSheet({super.key});

  @override
  State<CancelReasonBottomSheet> createState() =>
      _CancelReasonBottomSheetState();
}

class _CancelReasonBottomSheetState extends State<CancelReasonBottomSheet> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isOtherSelected = false;

  // أسباب محددة مسبقاً
  final List<String> _predefinedReasons = [
    'المطعم مشغول جداً',
    'نفاد المكونات',
    'عطل فني في المطبخ',
    'مشكلة في التوصيل',
    'خارج منطقة التوصيل',
    'سبب آخر',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: GoldenRatio.xl,
        right: GoldenRatio.xl,
        top: GoldenRatio.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + GoldenRatio.xl,
      ),
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(GoldenRatio.xl),
          topRight: Radius.circular(GoldenRatio.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سبب رفض الطلب',
                style: TypographySystem.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: WhizzColors.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: WhizzColors.onSurface),
              ),
            ],
          ),
          SizedBox(height: GoldenRatio.lg),

          // Subtitle
          Text(
            'الرجاء اختيار سبب رفض الطلب:',
            style: TypographySystem.bodyMedium.copyWith(
              color: WhizzColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: GoldenRatio.xl),

          // قائمة الأسباب
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _predefinedReasons.length,
              itemBuilder: (context, index) {
                final reason = _predefinedReasons[index];
                final isSelected = _selectedReason == reason;
                final isOtherOption = reason == 'سبب آخر';

                return Padding(
                  padding: EdgeInsets.only(bottom: GoldenRatio.md),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedReason = reason;
                        _isOtherSelected = isOtherOption;
                        if (!isOtherOption) {
                          _customReasonController.clear();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    child: Container(
                      padding: EdgeInsets.all(GoldenRatio.lg),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? WhizzColors.primary.withOpacity(0.1)
                            : WhizzColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(GoldenRatio.md),
                        border: Border.all(
                          color: isSelected
                              ? WhizzColors.primary
                              : WhizzColors.borderPrimary,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? WhizzColors.primary
                                : WhizzColors.onSurfaceVariant,
                          ),
                          SizedBox(width: GoldenRatio.md),
                          Expanded(
                            child: Text(
                              reason,
                              style: TypographySystem.bodyLarge.copyWith(
                                color: isSelected
                                    ? WhizzColors.primary
                                    : WhizzColors.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // TextField للسبب المخصص
          if (_isOtherSelected) ...[
            SizedBox(height: GoldenRatio.lg),
            TextField(
              controller: _customReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب السبب هنا...',
                hintStyle: TypographySystem.bodyMedium.copyWith(
                  color: WhizzColors.onSurfaceVariant,
                ),
                filled: true,
                fillColor: WhizzColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GoldenRatio.md),
                  borderSide: BorderSide(color: WhizzColors.borderPrimary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GoldenRatio.md),
                  borderSide: BorderSide(color: WhizzColors.borderPrimary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GoldenRatio.md),
                  borderSide: BorderSide(color: WhizzColors.primary, width: 2),
                ),
              ),
            ),
          ],

          SizedBox(height: GoldenRatio.xl),

          // أزرار التأكيد والإلغاء
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: WhizzColors.borderPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GoldenRatio.md),
                    ),
                    padding: EdgeInsets.symmetric(vertical: GoldenRatio.lg),
                  ),
                  child: Text(
                    'إلغاء',
                    style: TypographySystem.labelLarge.copyWith(
                      color: WhizzColors.onSurface,
                    ),
                  ),
                ),
              ),
              SizedBox(width: GoldenRatio.lg),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selectedReason == null
                      ? null
                      : () {
                          String finalReason = _selectedReason!;
                          if (_isOtherSelected &&
                              _customReasonController.text.trim().isNotEmpty) {
                            finalReason = _customReasonController.text.trim();
                          }
                          Navigator.pop(context, finalReason);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WhizzColors.error,
                    foregroundColor: WhizzColors.onPrimary,
                    disabledBackgroundColor:
                        WhizzColors.error.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GoldenRatio.md),
                    ),
                    padding: EdgeInsets.symmetric(vertical: GoldenRatio.lg),
                  ),
                  child: Text(
                    'تأكيد الرفض',
                    style: TypographySystem.labelLarge.copyWith(
                      color: WhizzColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
