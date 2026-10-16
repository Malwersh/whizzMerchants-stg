import 'package:flutter/material.dart';
import '../services/app_auth_service.dart';

class IraqiPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const IraqiPhoneField(
      {super.key, required this.controller, this.enabled = true});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'هاتف الفرع — اختياري، الافتراضي هاتف المالك',
            hintText: '07XX XXX XXXX',
            prefixIcon: Icon(Icons.phone_iphone),
            helperText: 'رقم عراقي 🇮🇶 (+964)',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null ||
                  value.trim().isEmpty ||
                  AppAuthService.normalizeIraqiPhone(value) != null
              ? null
              : 'أدخل رقم هاتف عراقي صحيحًا مثل 07XX XXX XXXX',
        ),
      );
}
